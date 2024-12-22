# Smart Walking Stick (IoT Prototype)

This repository contains the source code and documentation for a prototype **Smart Walking Stick**—an IoT-based solution that integrates real-time sensor monitoring, fall detection, and caregiver notifications for elderly users.

## Table of Contents

1. [Introduction](#introduction)  
2. [Repository Structure](#repository-structure)  
3. [Key Features](#key-features)  
4. [Quick Start](#quick-start)  
   - [Prerequisites](#prerequisites)  
   - [Installation and Setup](#installation-and-setup)  
   - [Running and Testing](#running-and-testing)  
5. [Project Details](#project-details)  
   - [Device](#device)  
   - [Edge (Mobile App)](#edge-mobile-app)  
   - [Cloud](#cloud)  
6. [Data Files](#data-files)  
7. [Future Improvements](#future-improvements)  
8. [License](#license)

---

## Introduction

As the global population ages, ensuring safety and autonomy for elderly individuals becomes critical. Current mobility aids often lack proactive monitoring to reduce the risk of falls. This **Smart Walking Stick** addresses those limitations by pairing real-time sensor data with mobile and cloud analytics. It offers:

- **Device-level** monitoring of grip strength and IMU data (accelerometer, gyroscope, etc.).  
- **Edge-level** real-time alerts on a smartphone application using BLE data streaming.  
- **Cloud-level** analytics, storage, and caregiver notifications.

---

## Repository Structure

```
root/
├── stick_app/
│   └── (...Flutter project for the mobile/edge application...)
├── stick_device/
│   └── (...PlatformIO Zephyr-based firmware for the smart stick...)
├── stick_cloud/
│   ├── lambda1.py
│   ├── lambda2.py
│   ├── lambda3.py
│   └── lambda4.py
├── selected.csv
├── selected3.csv
├── selected4.csv
├── selectedNoTembleque.csv
├── selectedTembleque.csv
└── README.md
```

1. **stick_app/**  
   - Contains the Flutter project for the **Edge Application** (Android/iOS).
   - Code for BLE discovery, data decoding, and UI flows (login, registration, data visualization).

2. **stick_device/**  
   - Contains the PlatformIO/Zephyr source code for the **Smart Walking Stick** firmware.
   - Implements BLE communication, sensor simulation, and device modes (walking, wobbly walking, falling, etc.).

3. **stick_cloud/**  
   - Contains the Python Lambda functions for AWS:
     - `notify_emergency`  
     - `get_data`  
     - `send_data`  
     - `check_tembleque`
   - Responsible for emergency notifications, sensor data storage (DynamoDB), GPS data retrieval, and imbalance detection.

4. **CSV Files**  
   - Sample data files (`selected.csv`, `selectedNoTembleque.csv`, etc.) used for additional analysis or testing.

---

## Key Features

- **BLE (Bluetooth Low Energy) Integration**:  
  Real-time data transmission from the walking stick to a mobile device.

- **Sensor Simulation**:  
  Simulated IMU data (accelerometer, gyroscope, magnetometer), pressure (grip strength), and battery level.

- **Mode Control**:  
  Multiple states (Walking, Wobbly Walking, Falling, Emergency) for realistic data patterns.

- **Mobile (Edge) Application**:  
  - Written in **Flutter** for Android/iOS.  
  - Provides UI for user login, real-time sensor updates, emergency alerts.

- **AWS Cloud Services**:  
  - **AWS Cognito** for user authentication and session management.  
  - **AWS DynamoDB** for storing sensor data.  
  - **AWS Lambda** for serverless data processing and emergency notifications.  
  - **AWS API Gateway** for orchestrating REST APIs.

---

## Quick Start

### Prerequisites

- **Flutter** SDK (for the **stick_app**):
  - [Installation Guide](https://docs.flutter.dev/get-started/install)
- **PlatformIO** (for the **stick_device**):
  - [Installation Guide](https://platformio.org/install)
- **AWS** account (if you intend to deploy the **stick_cloud** Lambda functions):
  - Basic knowledge of AWS Lambda, Cognito, API Gateway, and DynamoDB configuration.

### Installation and Setup

1. **Clone the Repository**

   ```bash
   git clone https://github.com/YourUsername/smart-walking-stick.git
   cd smart-walking-stick
   ```

2. **Set Up the Device Firmware** (optional if you only want to review code)
   - Navigate to `stick_device/`  
   - Open the project in [PlatformIO IDE](https://platformio.org/install/ide) or use the CLI.  
   - Update any board-specific settings if needed in `platformio.ini`.

3. **Set Up the Flutter App**  
   - Navigate to `stick_app/`:
     ```bash
     cd stick_app
     flutter pub get
     ```
   - Configure the app with your AWS Cognito details in `lib/config/config.dart` (user pool ID, client ID, region, etc.).  

4. **Set Up AWS Cloud (optional if you only want to review code)**  
   - Deploy the Lambda functions in **stick_cloud/**:
     - Each `.py` file can be zipped and uploaded to a Lambda function in AWS, or you can use AWS SAM/Serverless Framework.
   - Configure the AWS API Gateway routes (`/emergency`, `/sensor-data`, `/GPS`) to point to the respective Lambda functions.
   - Set up an **AWS Cognito** user pool with matching attributes (StickCode, Type) as referenced in the app.

### Running and Testing

- **Firmware**:  
  ```bash
  # In stick_device/
  platformio run
  platformio upload   # to flash your device (if connected)
  platformio device monitor  # to view serial output
  ```

- **Flutter App**:  
  ```bash
  # In stick_app/
  flutter run
  ```
  Follow on-screen instructions in the emulator/physical device.

- **Cloud**:  
  - Ensure your AWS resources are deployed and the endpoints are configured.
  - Test the endpoints with a REST client (e.g., Postman or curl) using the Cognito JWT token for authorization.

---

## Project Details

### Device

- **BLE Advertising & Notifications**  
  - Initializes BLE with `bt_enable`  
  - Defines a custom GATT service and characteristics for sensor data.  
  - Periodically sends notifications of IMU, pressure, battery level, and current operational mode.

- **Sensor Simulation**  
  - Accelerometer, Gyroscope, Magnetometer: Simulated using random or deterministic values.  
  - Pressure Sensor: Represents user grip strength on the stick handle.  
  - Battery: Decremented over time to emulate real consumption.

### Edge (Mobile App)

- **Flutter** application with screens for:
  - **Login/Sign Up** (integrated with AWS Cognito)  
  - **Verification** (enters code from email)  
  - **Supervisor Screen**: Displays the route map of the walking stick.  
  - **Carrier Screen**: Manages BLE connection, receives real-time sensor data, and sends emergency alerts.

- **Data Handling**:
  - Decodes raw BLE packets into structured JSON.  
  - Posts data to **/sensor-data** endpoint in AWS via API Gateway.  
  - Requests GPS data from **/GPS** endpoint for real-time route visualization.  

### Cloud

- **AWS API Gateway**  
  - Endpoints: `/emergency`, `/GPS`, `/sensor-data`.  

- **AWS Lambda Functions**  
  1. **notify_emergency**: Sends email alerts to supervisors.  
  2. **get_data**: Returns GPS coordinates for a given date.  
  3. **send_data**: Receives sensor data and saves it to **DynamoDB**.  
  4. **check_tembleque**: Periodically checks the latest data for falls/imbalance and notifies supervisors.

- **AWS Cognito**  
  - Handles user registration, login, and session token management.  
  - Custom attributes: `StickCode`, `Type` (Carrier or Supervisor).

- **DynamoDB**  
  - Stores sensor and GPS data keyed by `(stick_code, timestamp)`.

---

## Data Files

- **`selected.csv`, `selected3.csv`, `selected4.csv`, `selectedNoTembleque.csv`, `selectedTembleque.csv`**  
  - Sample CSV files with example sensor data or logs (for local testing/analysis).  
  - Not essential to run the system but can be used for analytics or to demonstrate data patterns.

---

## Future Improvements

1. **ML-based Fall Detection**:  
   Integrate a machine-learning model (e.g., Amazon SageMaker) to analyze sensor data for more accurate fall prediction.  
2. **Automatic Firmware Updates**:  
   Add OTA updates to allow the device to receive software upgrades automatically.  
3. **Expanded Dashboard**:  
   Provide a richer visualization with historical data and advanced analytics for caregivers.  

---

## License

This project is released under the [MIT License](LICENSE). You are free to modify and distribute it as described in the license terms.

---

**Questions or Feedback?**  
Please open an issue or reach out via pull requests if you have ideas for improvements or encounter any bugs. 

Enjoy exploring and enhancing the **Smart Walking Stick** project!
