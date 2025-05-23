import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import 'cubit/ble_cubit.dart';

void main() {
  // Optional: Customize logging
  // FlutterBluePlus.setLogLevel(LogLevel.verbose, color: true);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => BleCubit(), // Create the Cubit instance
      child: MaterialApp(
        title: 'Pico WiFi Provisioning',
        theme: ThemeData(primarySwatch: Colors.blue, useMaterial3: true),
        home: const BleControlScreen(),
      ),
    );
  }
}

class BleControlScreen extends StatefulWidget {
  const BleControlScreen({super.key});

  @override
  State<BleControlScreen> createState() => _BleControlScreenState();
}

class _BleControlScreenState extends State<BleControlScreen> {
  final _ssidController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _saveNetwork = true;

  @override
  void dispose() {
    _ssidController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pico WiFi Provisioning'),
        actions: [
          // Scan Button - Conditional based on state
          BlocBuilder<BleCubit, BleState>(
            builder: (context, state) {
              if (state.adapterState == BluetoothAdapterState.on &&
                  state.connectionState ==
                      BluetoothConnectionState.disconnected) {
                return IconButton(
                  icon: Icon(state.isScanning ? Icons.stop : Icons.search),
                  tooltip: state.isScanning ? 'Stop Scan' : 'Start Scan',
                  onPressed:
                      state.isScanning
                          ? () => context.read<BleCubit>().stopScan()
                          : () => context.read<BleCubit>().startScan(),
                );
              }
              return const SizedBox.shrink(); // Hide if BT off or connected
            },
          ),
        ],
      ),
      body: BlocConsumer<BleCubit, BleState>(
        listener: (context, state) {
          // Show Snackbars for errors or important status messages
          if (state.errorMessage != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.errorMessage!),
                backgroundColor: Colors.red,
              ),
            );
            // Optionally clear the error after showing
            // context.read<BleCubit>().emit(state.copyWith(clearErrorMessage: true));
          }
          if (state.statusMessage != null) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(state.statusMessage!)));
            // Optionally clear the message after showing
            // context.read<BleCubit>().emit(state.copyWith(clearStatusMessage: true));
          }
        },
        builder: (context, state) {
          return ListView(
            // Use ListView for scrollability
            padding: const EdgeInsets.all(16.0),
            children: [
              // --- Bluetooth Status ---
              _buildBluetoothStatus(state),
              const Divider(),

              // --- Scan Results ---
              if (state.connectionState ==
                  BluetoothConnectionState.disconnected)
                _buildScanResults(context, state),

              // --- Connection Control ---
              if (state.selectedDevice != null)
                _buildConnectionControl(context, state),

              // --- Provisioning Section ---
              if (state.connectionState == BluetoothConnectionState.connected &&
                  state.servicesDiscovered)
                _buildProvisioningSection(context, state),

              // --- Loading Indicator ---
              if (state.isLoading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20.0),
                  child: Center(child: CircularProgressIndicator()),
                ),
            ],
          );
        },
      ),
    );
  }

  // Widget Building Helper Functions

  Widget _buildBluetoothStatus(BleState state) {
    String btStatusText;
    Color btStatusColor;

    switch (state.adapterState) {
      case BluetoothAdapterState.on:
        btStatusText = 'Bluetooth ON';
        btStatusColor = Colors.green;
        break;
      case BluetoothAdapterState.off:
        btStatusText = 'Bluetooth OFF';
        btStatusColor = Colors.red;
        break;
      case BluetoothAdapterState.unauthorized:
        btStatusText = 'Bluetooth Unauthorized';
        btStatusColor = Colors.orange;
        break;
      case BluetoothAdapterState.unavailable:
        btStatusText = 'Bluetooth Unavailable';
        btStatusColor = Colors.grey;
        break;
      default:
        btStatusText = 'Bluetooth State Unknown';
        btStatusColor = Colors.grey;
    }
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          btStatusText,
          style: TextStyle(color: btStatusColor, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildScanResults(BuildContext context, BleState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Scan Results:', style: Theme.of(context).textTheme.titleMedium),
        if (state.isScanning) const Text('Scanning...'),
        if (!state.isScanning && state.scanResults.isEmpty)
          const Text('No devices found.'),
        ...state.scanResults.map((result) {
          // Prefer advertised name, fallback to platform name or ID
          String name =
              result.advertisementData.advName.isNotEmpty
                  ? result.advertisementData.advName
                  : (result.device.platformName.isNotEmpty
                      ? result.device.platformName
                      : result.device.remoteId.toString());
          return ListTile(
            title: Text(name),
            subtitle: Text(result.device.remoteId.toString()),
            trailing: Text('${result.rssi} dBm'),
            onTap: () => context.read<BleCubit>().selectDevice(result.device),
          );
        }),
        const Divider(),
      ],
    );
  }

  Widget _buildConnectionControl(BuildContext context, BleState state) {
    String name =
        state.selectedDevice!.platformName.isNotEmpty
            ? state.selectedDevice!.platformName
            : state.selectedDevice!.remoteId.toString();
    String connectionStatusText;
    Color connectionStatusColor;
    bool canConnect =
        state.connectionState == BluetoothConnectionState.disconnected;
    bool canDisconnect =
        state.connectionState == BluetoothConnectionState.connected;

    // Connection Status
    switch (state.connectionState) {
      case BluetoothConnectionState.connected:
        connectionStatusText = 'Connected';
        connectionStatusColor = Colors.green;
        break;
      case BluetoothConnectionState.connecting:
        connectionStatusText = 'Connecting...';
        connectionStatusColor = Colors.orange;
        break;
      case BluetoothConnectionState.disconnected:
        connectionStatusText = 'Disconnected';
        connectionStatusColor = Colors.red;
        break;
      case BluetoothConnectionState.disconnecting:
        connectionStatusText = 'Disconnecting...';
        connectionStatusColor = Colors.orange;
        break;
    }

    // Bond Status
    String bondStatusText =
        'Bond: ${state.bondState.toString().split('.').last}';
    Color bondStatusColor;
    switch (state.bondState) {
      case BluetoothBondState.bonded:
        bondStatusColor = Colors.blue;
        break;
      case BluetoothBondState.bonding:
        bondStatusColor = Colors.orange;
        break;
      case BluetoothBondState.none:
        bondStatusColor = Colors.grey;
        break;
    }

    return Column(
      children: [
        ListTile(
          title: Text('Selected: $name'),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Status: $connectionStatusText',
                style: TextStyle(
                  color: connectionStatusColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                bondStatusText,
                style: TextStyle(color: bondStatusColor),
              ), // <-- Display Bond State
            ],
          ),
          trailing: ElevatedButton(
            onPressed:
                state.isLoading
                    ? null
                    : (canConnect // Disable while loading
                        ? () => context.read<BleCubit>().connectToDevice(
                          state.selectedDevice!,
                        )
                        : (canDisconnect
                            ? () => context.read<BleCubit>().disconnectDevice()
                            : null)),
            child: Text(
              canConnect
                  ? 'Connect'
                  : (canDisconnect ? 'Disconnect' : connectionStatusText),
            ),
          ),
        ),
        const Divider(),
      ],
    );
  }

  Widget _buildProvisioningSection(BuildContext context, BleState state) {
    bool canProvision =
        state.connectionState == BluetoothConnectionState.connected &&
        state.servicesDiscovered &&
        state.isPicoBonded; // must be bonded to provision

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Provision WiFi', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),

        if (!canProvision && !state.isPicoBonded)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Text(
              "Device must be bonded before sending credentials.",
              style: TextStyle(
                color: Colors.orange[700],
                fontStyle: FontStyle.italic,
              ),
              textAlign: TextAlign.center,
            ),
          ),

        TextField(
          controller: _ssidController,
          enabled:
              canProvision &&
              !state.isLoading, // Disable if not ready or loading
          decoration: const InputDecoration(
            labelText: 'WiFi SSID',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _passwordController,
          obscureText: _obscurePassword,
          enabled:
              canProvision &&
              !state.isLoading, // Disable if not ready or loading
          decoration: InputDecoration(
            labelText: 'WiFi Password',
            border: OutlineInputBorder(),
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePassword ? Icons.visibility_off : Icons.visibility,
              ),
              onPressed: () {
                setState(() {
                  _obscurePassword = !_obscurePassword;
                });
              },
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(
            vertical: 0.0,
          ), // Adjust padding as needed
          child: CheckboxListTile(
            title: const Text("Save network to Pico"),
            value: _saveNetwork,
            onChanged:
                (canProvision && !state.isLoading)
                    ? (bool? newValue) {
                      if (newValue != null) {
                        setState(() {
                          _saveNetwork = newValue;
                        });
                      }
                    }
                    : null, // Disable if not ready or loading
            controlAffinity: ListTileControlAffinity.leading,
            dense: true, // Makes the tile more compact
            contentPadding:
                EdgeInsets.zero, // Removes default padding if too much
          ),
        ),
        const SizedBox(height: 16),
        Center(
          child: ElevatedButton(
            onPressed:
                (state.isLoading || !canProvision)
                    ? null
                    : () {
                      // Disable if loading or not ready
                      final ssid = _ssidController.text;
                      final password = _passwordController.text;
                      if (ssid.isNotEmpty) {
                        context.read<BleCubit>().sendCredentials(
                          ssid,
                          password,
                          _saveNetwork, // Pass the checkbox value here
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('SSID cannot be empty'),
                            backgroundColor: Colors.orange,
                          ),
                        );
                      }
                    },
            child: const Text('Send Credentials & Connect WiFi'),
          ),
        ),
        const SizedBox(height: 10),
        const Center(),
        const Divider(),
      ],
    );
  }
}
