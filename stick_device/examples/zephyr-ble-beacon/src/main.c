#include <zephyr/types.h>
#include <stddef.h>
#include <string.h>
#include <errno.h>
#include <sys/printk.h>
#include <sys/byteorder.h>
#include <zephyr.h>
#include <random/rand32.h> // Para valores aleatorios

#include <bluetooth/bluetooth.h>
#include <bluetooth/hci.h>
#include <bluetooth/conn.h>
#include <bluetooth/uuid.h>
#include <bluetooth/gatt.h>

#include <device.h>
#include <drivers/gpio.h>

// Pines de los botones en la nRF52840-DK
#define BUTTON_1_PIN 11  // P0.11
#define BUTTON_2_PIN 12  // P0.12
#define BUTTON_3_PIN 24  // P0.24
#define BUTTON_4_PIN 25  // P0.25

// Pin del LED1 en la nRF52840-DK (LED1 suele estar en P0.13)
#define LED1_PIN 13 

// Dispositivo GPIO (normalmente "GPIO0" en nRF52840-DK)
static const struct device *gpio_dev;

// Variables para LED
static bool led1_state = false; // Estado del LED1 (apagado inicialmente)

// UUIDs personalizados
#define BT_UUID_CUSTOM_SERVICE BT_UUID_DECLARE_128(0x12345678, 0x1234, 0x5678, 0x1234, 0x56789abcdef0)
#define BT_UUID_SENSOR_DATA    BT_UUID_DECLARE_128(0xabcdef12, 0x3456, 0x7890, 0x1234, 0x56789abcdef1)

// Datos del sensor
static float accelerometer_data[3] = {0.0f, 0.0f, 9.8f};
static float gyroscope_data[3] = {0.0f, 0.0f, 0.0f};
static float magnetometer_data[3] = {30.0f, -15.0f, 42.0f};
static float pressure_data[2] = {20.0f, 22.0f};
static float battery_level = 85.0f;

// Ahora el buffer es más grande para incluir el modo
// Máximo para ACC/GYR/MAG: 14 bytes (1 ID + 12 data + 1 modo)
static uint8_t sensor_buffer[14];

// Modo actual (1: caminando normal, 2: caída, 3: caminar tambaleándose, 4: quieto)
static int mode = 1; 

// Variables para gestionar la caída
static int fall_state = 0; // 0: caminando, 1: impacto, 2: tumbado
static int fall_counter = 0;

BT_GATT_SERVICE_DEFINE(custom_service,
    BT_GATT_PRIMARY_SERVICE(BT_UUID_CUSTOM_SERVICE),
    BT_GATT_CHARACTERISTIC(BT_UUID_SENSOR_DATA, BT_GATT_CHRC_NOTIFY,
                           BT_GATT_PERM_NONE, NULL, NULL, NULL),
    BT_GATT_CCC(NULL, BT_GATT_PERM_READ | BT_GATT_PERM_WRITE),
);

// Prototipos
static void simulate_walking(void);
static void simulate_fall_sequence(void);
static void simulate_fall_impact(void);
static void simulate_stick_fall(void);
static void simulate_wobbly_walking(void);
static void simulate_standing_still(void);

// Simula caminar apoyado en el bastón (normal, más estable)
static void simulate_walking(void) {
    // Rango muy reducido para simular estabilidad: 
    for (int i = 0; i < 3; i++) {
        accelerometer_data[i] = ((float)((int32_t)(sys_rand32_get() % 5) - 2)) / 100.0f; 
        gyroscope_data[i] = ((float)((int32_t)(sys_rand32_get() % 5) - 2)) / 100.0f;
    }

    // Presión con muy poca variabilidad
    pressure_data[0] = 20.0f + ((float)((int32_t)(sys_rand32_get() % 3) - 1)) / 10.0f;
    pressure_data[1] = 22.0f + ((float)((int32_t)(sys_rand32_get() % 3) - 1)) / 10.0f;

    printk("Simulación: Caminando normal (más estable)\n");
}

static void simulate_wobbly_walking(void) {
    for (int i = 0; i < 3; i++) {
        accelerometer_data[i] = ((float)((int32_t)(sys_rand32_get() % 2001) - 1000)) / 50.0f; 
        gyroscope_data[i] = ((float)((int32_t)(sys_rand32_get() % 2001) - 1000)) / 50.0f;
        if (sys_rand32_get() % 5 == 0) {
            accelerometer_data[i] += (float)((sys_rand32_get() % 1001) - 500) / 10.0f;
            gyroscope_data[i] += (float)((sys_rand32_get() % 1001) - 500) / 10.0f;
        }
    }

    pressure_data[0] = 20.0f + ((float)((int32_t)(sys_rand32_get() % 101) - 50)) / 5.0f;
    pressure_data[1] = 22.0f + ((float)((int32_t)(sys_rand32_get() % 101) - 50)) / 5.0f;

    printk("Simulación: Caminando tambaleándose (más exagerado)\n");
}

static void simulate_fall_impact(void) {
    accelerometer_data[0] = (float)((sys_rand32_get() % 20) + 20);
    accelerometer_data[1] = (float)((int32_t)(sys_rand32_get() % 21) - 10);
    accelerometer_data[2] = (float)((int32_t)(sys_rand32_get() % 41) - 20);

    gyroscope_data[0] = (float)(sys_rand32_get() % 200) / 10.0f;
    gyroscope_data[1] = (float)(sys_rand32_get() % 200) / 10.0f;
    gyroscope_data[2] = (float)(sys_rand32_get() % 200) / 10.0f;

    pressure_data[0] = 50.0f;
    pressure_data[1] = 50.0f;

    printk("Simulación: Impacto de la caída\n");
}

static void simulate_stick_fall(void) {
    accelerometer_data[0] = 0.0f;
    accelerometer_data[1] = 9.8f;
    accelerometer_data[2] = 0.0f;

    gyroscope_data[0] = 0.0f;
    gyroscope_data[1] = 0.0f;
    gyroscope_data[2] = 0.0f;

    pressure_data[0] = 0.0f;
    pressure_data[1] = 0.0f;

    printk("Simulación: Bastón tumbado\n");
}

static void simulate_fall_sequence(void) {
    if (fall_state == 0) {
        if (fall_counter < 3) {
            simulate_walking();
            fall_counter++;
        } else {
            fall_state = 1;
            fall_counter = 0;
            simulate_fall_impact();
        }
    } else if (fall_state == 1) {
        if (fall_counter < 1) {
            simulate_fall_impact();
            fall_counter++;
        } else {
            fall_state = 2;
            fall_counter = 0;
            simulate_stick_fall();
        }
    } else if (fall_state == 2) {
        simulate_stick_fall();
    }
}

static void simulate_standing_still(void) {
    accelerometer_data[0] = 0.0f;
    accelerometer_data[1] = 0.0f;
    accelerometer_data[2] = 9.8f;

    gyroscope_data[0] = 0.0f;
    gyroscope_data[1] = 0.0f;
    gyroscope_data[2] = 0.0f;

    pressure_data[0] = 20.0f;
    pressure_data[1] = 22.0f;

    printk("Simulación: Quieto\n");
}

static void send_sensor_data(void)
{
    // Acelerómetro (14 bytes)
    sensor_buffer[0] = 0x01;
    memcpy(&sensor_buffer[1], accelerometer_data, sizeof(accelerometer_data));
    sensor_buffer[13] = (uint8_t)mode; 
    bt_gatt_notify(NULL, &custom_service.attrs[1], sensor_buffer, 14);

    // Giroscopio (14 bytes)
    sensor_buffer[0] = 0x02;
    memcpy(&sensor_buffer[1], gyroscope_data, sizeof(gyroscope_data));
    sensor_buffer[13] = (uint8_t)mode;
    bt_gatt_notify(NULL, &custom_service.attrs[1], sensor_buffer, 14);

    // Magnetómetro (14 bytes)
    sensor_buffer[0] = 0x03;
    memcpy(&sensor_buffer[1], magnetometer_data, sizeof(magnetometer_data));
    sensor_buffer[13] = (uint8_t)mode;
    bt_gatt_notify(NULL, &custom_service.attrs[1], sensor_buffer, 14);

    // Presión (10 bytes)
    sensor_buffer[0] = 0x04;
    memcpy(&sensor_buffer[1], pressure_data, sizeof(pressure_data));
    sensor_buffer[9] = (uint8_t)mode;
    bt_gatt_notify(NULL, &custom_service.attrs[1], sensor_buffer, 10);

    // Batería (6 bytes)
    sensor_buffer[0] = 0x05;
    memcpy(&sensor_buffer[1], &battery_level, sizeof(battery_level));
    sensor_buffer[5] = (uint8_t)mode;
    bt_gatt_notify(NULL, &custom_service.attrs[1], sensor_buffer, 6);

    printk("Datos del sensor enviados (modo: %d):\n", mode);
    printk("Acelerómetro: X=%.2f, Y=%.2f, Z=%.2f\n", accelerometer_data[0], accelerometer_data[1], accelerometer_data[2]);
    printk("Giroscopio: X=%.2f, Y=%.2f, Z=%.2f\n", gyroscope_data[0], gyroscope_data[1], gyroscope_data[2]);
    printk("Magnetómetro: X=%.2f, Y=%.2f, Z=%.2f\n", magnetometer_data[0], magnetometer_data[1], magnetometer_data[2]);
    printk("Presión: S1=%.2f, S2=%.2f\n", pressure_data[0], pressure_data[1]);
    printk("Batería: %.2f%%\n", battery_level);
}

static void bt_ready(void)
{
    int err;

    printk("Bluetooth initialized\n");

    err = bt_le_adv_start(BT_LE_ADV_CONN_NAME, NULL, 0, NULL, 0);
    if (err) {
        printk("Advertising failed to start (err %d)\n", err);
        return;
    }

    printk("Advertising successfully started\n");
}

// Callback para los botones
static struct gpio_callback button_cb_data;

void button_pressed(const struct device *dev, struct gpio_callback *cb, uint32_t pins)
{
    if (pins & BIT(BUTTON_1_PIN)) {
        // Cada vez que se pulsa el botón 1, se establece el modo 1.
        mode = 1;
        // Alternamos el LED
        led1_state = !led1_state;
        gpio_pin_set(gpio_dev, LED1_PIN, (int)led1_state);
        
        printk("Botón 1 pulsado: Modo = 1 (Caminando normal), LED1 %s\n", led1_state ? "encendido" : "apagado");
        
        // Reiniciar estado de caida por si estaba en otro modo
        fall_state = 0; 
        fall_counter = 0;
    } else if (pins & BIT(BUTTON_2_PIN)) {
        mode = 2; // Modo caída
        fall_state = 0; 
        fall_counter = 0;
        printk("Botón 2 pulsado: Modo = 2 (Caída)\n");
    } else if (pins & BIT(BUTTON_3_PIN)) {
        mode = 3; // Modo tambaleándose
        fall_state = 0; 
        fall_counter = 0;
        printk("Botón 3 pulsado: Modo = 3 (Caminando tambaleándose)\n");
    } else if (pins & BIT(BUTTON_4_PIN)) {
        mode = 4; // Modo quieto
        fall_state = 0; 
        fall_counter = 0;
        printk("Botón 4 pulsado: Modo = 4 (Quieto)\n");
    }
}

static void buttons_init(void)
{
    gpio_dev = DEVICE_DT_GET(DT_NODELABEL(gpio0));
    if (!device_is_ready(gpio_dev)) {
        printk("Error: gpio0 no está listo\n");
        return;
    }

    // Configurar pines de botones como entrada con pull-up
    gpio_pin_configure(gpio_dev, BUTTON_1_PIN, GPIO_INPUT | GPIO_PULL_UP);
    gpio_pin_configure(gpio_dev, BUTTON_2_PIN, GPIO_INPUT | GPIO_PULL_UP);
    gpio_pin_configure(gpio_dev, BUTTON_3_PIN, GPIO_INPUT | GPIO_PULL_UP);
    gpio_pin_configure(gpio_dev, BUTTON_4_PIN, GPIO_INPUT | GPIO_PULL_UP);

    // Configurar interrupciones
    gpio_pin_interrupt_configure(gpio_dev, BUTTON_1_PIN, GPIO_INT_EDGE_TO_ACTIVE);
    gpio_pin_interrupt_configure(gpio_dev, BUTTON_2_PIN, GPIO_INT_EDGE_TO_ACTIVE);
    gpio_pin_interrupt_configure(gpio_dev, BUTTON_3_PIN, GPIO_INT_EDGE_TO_ACTIVE);
    gpio_pin_interrupt_configure(gpio_dev, BUTTON_4_PIN, GPIO_INT_EDGE_TO_ACTIVE);

    gpio_init_callback(&button_cb_data, button_pressed,
                       BIT(BUTTON_1_PIN) | BIT(BUTTON_2_PIN) | BIT(BUTTON_3_PIN) | BIT(BUTTON_4_PIN));
    gpio_add_callback(gpio_dev, &button_cb_data);

    printk("Botones inicializados\n");
}

static void leds_init(void)
{
    // Configurar el pin del LED1 como salida
    gpio_pin_configure(gpio_dev, LED1_PIN, GPIO_OUTPUT_INACTIVE);
    led1_state = false;
}

void main(void)
{
    int err;

    // Inicializar Bluetooth
    err = bt_enable(NULL);
    if (err) {
        printk("Bluetooth init failed (err %d)\n", err);
        return;
    }

    bt_ready();

    printk("Custom GATT service registered\n");

    // Inicializar botones y LED
    buttons_init();
    leds_init();

    while (1) {
        k_sleep(K_SECONDS(1));

        // Actualizar datos según el modo seleccionado
        switch (mode) {
            case 1:
                simulate_walking();
                break;
            case 2:
                simulate_fall_sequence();
                break;
            case 3:
                simulate_wobbly_walking();
                break;
            case 4:
                simulate_standing_still();
                break;
            default:
                printk("Modo desconocido: %d\n", mode);
                break;
        }

        // Enviar datos
        send_sensor_data();

        // Simular drenaje de batería
        battery_level -= 0.1f;
        if (battery_level < 0.0f) battery_level = 85.0f;
    }
}
