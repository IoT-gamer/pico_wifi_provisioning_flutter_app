# **Pico WiFi Provisioning Flutter Tester App**

This Flutter application serves as a testing and demonstration tool for the [pico-wifi-provisioning](https://github.com/IoT-gamer/pico-wifi-provisioning) library, which enables WiFi provisioning for Raspberry Pi Pico W boards over Bluetooth Low Energy (BLE).

The app allows users to scan for Pico W devices advertising the specific device name, connect to them, and send WiFi credentials (SSID and password) to configure the Pico W's network connection.

## **Overview**

The primary purpose of this app is to:

1. Discover nearby Raspberry Pi Pico W devices set up for BLE WiFi provisioning.  
2. Establish a secure BLE connection with a selected Pico W.  
3. Send encrypted WiFi network credentials (SSID and password) to the Pico W.  
4. Command the Pico W to save the network and/or connect to the specified WiFi.  
5. Provide feedback on the provisioning process.

This app is built using Flutter and utilizes the [flutter_blue_plus](https://pub.dev/packages/flutter_blue_plus) package for BLE communication and [flutter_bloc](https://pub.dev/packages/flutter_bloc) (Cubit) for state management.

## **Related Library & Exmple PlatformIO Project**

This application is designed to work in conjunction with the firmware and BLE services defined in the following repository:

[Pico WiFi Provisioning Library:](https://github.com/IoT-gamer/pico-wifi-provisioning)

and its example project:

[BasicProvisioning PlatformIO Project:](https://github.com/IoT-gamer/pico-wifi-provisioning/tree/main/examples/BasicProvisioning)


Ensure your Raspberry Pi Pico W is flashed with the firmware from the above project to be compatible with this app.

## **Features**

* **BLE Device Scanning:** Scans for nearby BLE devices, specifically filtering for those advertising the name "PicoWiFi".  
* **Device Connection:** Connects to a selected Pico W device.  
* **Service Discovery:** Discovers the required BLE services and characteristics for WiFi provisioning.  
* **Bonding Management:**  
  * Displays the current BLE bond state with the Pico.  
  * Monitors the Pico's self-reported bonding status.  
  * Ensures credentials are sent only over a bonded connection.  
  * Option to remove bond (Android only).  
* **Credential Input:** Secure input fields for WiFi SSID and password.  
* **Save Network Option:** Allows the user to choose whether the Pico W should save the network credentials persistently.  
* **Send Credentials & Connect:** Transmits the SSID, password, and control commands to the Pico W.  
* **Status Updates:** Provides real-time feedback on Bluetooth adapter state, scanning status, connection state, and provisioning steps.  
* **Error Handling:** Displays informative error messages for common issues (e.g., Bluetooth off, connection failed, services not found).  
* **User-Friendly Interface:** Simple UI for easy interaction.

## **How it Works (BLE Communication Flow)**

The app follows these general steps to provision a Pico W:

1. **Adapter Check:** Verifies that Bluetooth is enabled on the mobile device.  
2. **Scan for Pico:** Scans for BLE devices advertising the name "PicoWiFi".  
3. **Select & Connect:** User selects a Pico device from the list, and the app establishes a BLE connection.  
4. **Discover Services:** The app discovers the predefined GATT services and characteristics on the Pico W:  
   * **Service UUID:** 5a67d678-6361-4f32-8396-54c6926c8fa1  
   * **SSID Characteristic UUID:** 5a67d678-6361-4f32-8396-54c6926c8fa2 (Write)  
   * **Password Characteristic UUID:** 5a67d678-6361-4f32-8396-54c6926c8fa3 (Write)  
   * **Command Characteristic UUID:** 5a67d678-6361-4f32-8396-54c6926c8fa4 (Write)  
   * **Pairing Status Characteristic UUID:** 5a67d678-6361-4f32-8396-54c6926c8fa5 (Notify/Read)  
5. **Bonding:** The app checks the bond state. If not bonded, the OS may initiate the bonding/pairing process. The app also subscribes to the Pico's pairing status characteristic to confirm the Pico acknowledges the bond. Credentials are only sent if a secure, bonded connection is established.  
6. **Input Credentials:** The user enters the WiFi SSID and password and selects if the network should be saved on the Pico.  
7. **Send Data:**  
   * The SSID is written to the SSID characteristic.  
   * The password is written to the password characteristic.  
   * If "Save Network" is selected, 0x01 (CMD_SAVE_NETWORK) is written to the command characteristic.  
   * 0x02 (CMD_CONNECT) is written to the command characteristic to instruct the Pico to attempt a WiFi connection.  
8. **Pico Action & Disconnection:** The Pico W processes the received credentials and commands. It will then attempt to connect to the WiFi network. Typically, the BLE connection is terminated by the Pico W after provisioning is complete or initiated.

## **Screenshots**

* [App main screen](docs/screenshots/main_screen.jpg) 
   * click search icon (located in top right of screen) to start scanning for devices
* [App scanning for devices](docs/screenshots/scanning.jpg) 
   * click on a device to stop scanning
* [Device connection screen](docs/screenshots/connect.jpg) 
   * click "Connect" to connect with the device
* [Pairing/Bonding screen](docs/screenshots/pairing.jpg)
   * Androdid will show a pairing request dialog (may appear twice)
   * click "Pair" to pair/bond with the device
* [WiFi credential input form](docs/screenshots/credentials.jpg) 
   * enter your WiFi SSID and password
   * click "Send Credentials & Connect WiFi" to send the data to the Pico W
   * check "Save network to Pico" if you want the Pico W to remember these credentials for future connections

## **Setup and Installation**

1. **Clone the repository:**  
   git clone https://github.com/IoT-gamer/pico_wifi_provisioning_flutter_app.git  
   cd pico_wifi_provisioning_flutter_app

2. **Ensure Flutter is installed:** If not, follow the [official Flutter installation guide](https://flutter.dev/docs/get-started/install).  
3. **Get dependencies:**  
   flutter pub get

4. **Run the app:**  
   flutter run

### **Bluetooth Permissions**

The app will request necessary Bluetooth permissions (e.g., location for scanning on Android, Bluetooth permission on iOS and Android 12+). Please grant these permissions for the app to function correctly.

## **Usage Guide**

1. **Prepare Pico W:** Ensure your Raspberry Pi Pico W is powered on and running the firmware from the [BasicProvisioning](https://github.com/IoT-gamer/pico-wifi-provisioning/tree/main/examples/BasicProvisioning) project. It should be advertising as "PicoWiFi".  
2. **Open the App:** Launch the Pico WiFi Provisioning Flutter app on your mobile device.  
3. **Enable Bluetooth:** If Bluetooth is off, the app will indicate this. Please enable Bluetooth on your device.  
4. **Scan for Devices:**  
   * Tap the "Scan" icon (magnifying glass) in the app bar.  
   * The app will list discovered "PicoWiFi" devices.  
5. **Select Your Pico:** Tap on your Pico W device from the list.  
6. **Connect & Bond:**  
   * The app will display the selected device. Tap the "Connect" button.  
   * If your phone hasn't bonded with the Pico W before, the operating system might prompt you to pair/bond. Accept the pairing request.  
   * The app will show "Connected" and the bond status once successful. The "Provision WiFi" section will become active only when the device is bonded.  
7. **Enter WiFi Credentials:**  
   * In the "Provision WiFi" section, enter your WiFi network's **SSID** (name).  
   * Enter the WiFi **Password**. You can tap the visibility icon to show/hide the password.  
   * Check the "Save network to Pico" box if you want the Pico W to remember these credentials for future connections.  
8. **Send Credentials:**  
   * Tap the "Send Credentials & Connect WiFi" button.  
   * The app will send the data to the Pico W.  
9. **Monitor Status:**  
   * The app will display a status message indicating that credentials have been sent and the Pico is attempting to connect.  
   * The BLE connection will likely be terminated by the Pico W as it reconfigures its network interface.  
10. **Verify Connection:** Check if your Pico W has successfully connected to the WiFi network (e.g., by observing its serial output, onboard LED or network activity).

## **Key Code Components**

* **lib/main.dart:** Contains the main application widget (MyApp) and the primary UI screen (BleControlScreen).  
* **lib/cubit/ble_cubit.dart:** Manages all BLE interaction logic, including scanning, connecting, service discovery, characteristic operations, and sending credentials. It extends Cubit from the flutter_bloc package.  
* **lib/cubit/ble_state.dart:** Defines the state object for BleCubit, holding all relevant data like adapter state, scan results, connection status, bond state, etc. It uses Equatable for efficient state comparisons.

## **Troubleshooting**

* **Bluetooth** is **Off/Unavailable:** Ensure Bluetooth is enabled on your phone and the app has the necessary permissions.  
* **Pico Not Found:**  
  * Verify the Pico W is powered and running the correct provisioning firmware.  
  * Ensure the Pico W is within BLE range.  
  * Check if the Pico W is advertising as "PicoWiFi".  
* **Connection Fails:**  
  * Try moving closer to the Pico W.  
  * Restart Bluetooth on your phone and power cycle the Pico W.  
  * If previously bonded, try removing the bond from your phone's Bluetooth settings and let the app re-bond.  
* **Services Not Discovered / Characteristics Not Found:**  
  * This usually indicates an issue with the Pico W's firmware or a problem during the BLE connection. Ensure the correct firmware is loaded on the Pico.  
* **Cannot Send Credentials (Button Disabled):**  
  * The "Send Credentials" button is enabled only when the app is connected to the Pico W, services are discovered, AND the device is reported as bonded (both by the OS and the Pico itself via its pairing status characteristic). If the Pico does not confirm it's bonded, you won't be able to send credentials.  
* **Pico Doesn't Connect to WiFi:**  
  * Double-check the SSID and password for typos.  
  * Ensure your WiFi network is 2.4GHz, as Pico W does not support 5GHz networks.  
  * Check the Pico W's serial output for any error messages related to WiFi connection attempts.

## **Contributing**

Contributions to this tester app are welcome! If you have suggestions for improvements or find any bugs, please feel free to open an issue or submit a pull request.

1. Fork the repository.  
2. Create your feature branch (git checkout -b feature/AmazingFeature).  
3. Commit your changes (git commit -m 'Add some AmazingFeature').  
4. Push to the branch (git push origin feature/AmazingFeature).  
5. Open a Pull Request.

## **License**

Distributed under the MIT License. See [LICENSE](LICENSE) file for more information.
