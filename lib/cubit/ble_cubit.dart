import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

part 'ble_state.dart';

class BleCubit extends Cubit<BleState> {
  final Guid _serviceUuid = Guid("5a67d678-6361-4f32-8396-54c6926c8fa1");
  final Guid _ssidCharUuid = Guid("5a67d678-6361-4f32-8396-54c6926c8fa2");
  final Guid _passwordCharUuid = Guid("5a67d678-6361-4f32-8396-54c6926c8fa3");
  final Guid _commandCharUuid = Guid("5a67d678-6361-4f32-8396-54c6926c8fa4");
  final Guid _pairingStatusCharUuid = Guid(
    "5a67d678-6361-4f32-8396-54c6926c8fa5",
  );

  BluetoothCharacteristic? _ssidChar;
  BluetoothCharacteristic? _passwordChar;
  BluetoothCharacteristic? _commandChar;
  BluetoothCharacteristic? _pairingStatusChar;

  StreamSubscription<BluetoothAdapterState>? _adapterStateSubscription;
  StreamSubscription<List<ScanResult>>? _scanResultsSubscription;
  StreamSubscription<List<int>>? _bondStatusValueSubscription;
  StreamSubscription<BluetoothConnectionState>? _connectionStateSubscription;

  BleCubit() : super(const BleState()) {
    _initBle();
  }

  // Checks and requests necessary permissions.
  Future<bool> checkPermissions() async {
    Map<Permission, PermissionStatus> statuses =
        await [
          Permission.bluetoothScan,
          Permission.bluetoothConnect,
          Permission.location,
        ].request();

    final scanPermission = statuses[Permission.bluetoothScan];
    final connectPermission = statuses[Permission.bluetoothConnect];
    final locationPermission = statuses[Permission.location];

    if (scanPermission == PermissionStatus.granted &&
        connectPermission == PermissionStatus.granted &&
        locationPermission == PermissionStatus.granted) {
      return true;
    } else {
      String errorMessage =
          'Please grant all required permissions to use the app.';
      if (scanPermission!.isPermanentlyDenied ||
          connectPermission!.isPermanentlyDenied ||
          locationPermission!.isPermanentlyDenied) {
        errorMessage =
            'Permissions are permanently denied. Please open app settings to grant them.';
        // Consider adding: openAppSettings();
      }
      emit(state.copyWith(errorMessage: errorMessage));
      return false;
    }
  }

  // Initialization
  Future<void> _initBle() async {
    // Call permission check first.
    if (Platform.isAndroid) {
      final permissionsGranted = await checkPermissions();
      if (!permissionsGranted) {
        // Stop initialization if permissions are not granted
        return;
      }
    }

    if (await FlutterBluePlus.isSupported == false) {
      emit(
        state.copyWith(errorMessage: "Bluetooth not supported by this device"),
      );
      return;
    }

    _adapterStateSubscription = FlutterBluePlus.adapterState.listen((
      adapterState,
    ) {
      emit(state.copyWith(adapterState: adapterState));
      if (adapterState == BluetoothAdapterState.on) {
        // Ready
      } else {
        // Reset state if bluetooth is turned off
        stopScan();
        _resetConnectionState();
        emit(
          state.copyWith(
            scanResults: [],
            selectedDevice: null,
            clearSelectedDevice: true,
            errorMessage: "Bluetooth is OFF", // More specific message
          ),
        );
      }
    });

    if (Platform.isAndroid) {
      await FlutterBluePlus.turnOn();
    }
  }

  Future<void> startScan() async {
    // Re-check permissions before starting a scan, in case they were revoked.
    if (Platform.isAndroid) {
      final permissionsGranted = await checkPermissions();
      if (!permissionsGranted) return;
    }

    if (state.adapterState != BluetoothAdapterState.on || state.isScanning) {
      return;
    }
    emit(
      state.copyWith(
        scanResults: [],
        isScanning: true,
        clearErrorMessage: true,
      ),
    );
    try {
      _scanResultsSubscription = FlutterBluePlus.onScanResults.listen(
        (results) {
          var uniqueResults = <ScanResult>[];
          var seenIds = <String>{};
          for (var r in results) {
            if (seenIds.add(r.device.remoteId.toString())) {
              uniqueResults.add(r);
            }
          }
          emit(state.copyWith(scanResults: uniqueResults));
        },
        onError: (e) {
          print("Scan Error: $e");
          emit(
            state.copyWith(isScanning: false, errorMessage: "Scan Error: $e"),
          );
        },
      );
      FlutterBluePlus.cancelWhenScanComplete(_scanResultsSubscription!);
      await FlutterBluePlus.startScan(
        // withServices: [_serviceUuid], // your device must actively advertise
        // the serviceUUIDs it supports
        withNames: ["PicoWiFi"],
        timeout: Duration(seconds: 15),
      );
      await FlutterBluePlus.isScanning.where((val) => val == false).first;
      if (!isClosed) {
        emit(state.copyWith(isScanning: false));
      }
    } catch (e) {
      print("Start Scan Error: $e");
      if (!isClosed) {
        emit(
          state.copyWith(
            isScanning: false,
            errorMessage: "Start Scan Error: $e",
          ),
        );
      }
    } finally {
      if (!isClosed && state.isScanning) {
        emit(state.copyWith(isScanning: false));
      }
    }
  }

  void stopScan() {
    FlutterBluePlus.stopScan();
    _scanResultsSubscription?.cancel();
    _scanResultsSubscription = null;
    if (state.isScanning) {
      emit(state.copyWith(isScanning: false));
    }
  }

  Future<void> selectDevice(BluetoothDevice device) async {
    print('selectDevice called with: ${device.remoteId}');
    stopScan(); // Stop scanning when a device is selected
    emit(state.copyWith(selectedDevice: device));
  }

  Future<void> connectToDevice(BluetoothDevice device) async {
    print('Connection State before: ${state.connectionState}');
    if (state.isLoading ||
        state.connectionState != BluetoothConnectionState.disconnected) {
      print("Already connecting or connected, or operation in progress.");
      return;
    }
    emit(
      state.copyWith(
        isLoading: true,
        statusMessage: "Connecting...",
        clearErrorMessage: true,
      ),
    );
    print("Attempting to connect to ${device.remoteId}...");

    // Try connecting
    try {
      print("Calling device.connect with timeout...");
      await device.connect(
        autoConnect: false,
        timeout: const Duration(seconds: 10),
      );
      print("device.connect() call returned.");
      emit(state.copyWith(connectionState: BluetoothConnectionState.connected));
      _connectionStateSubscription = device.connectionState.listen((
        connectionState,
      ) {
        print("Connection State Changed: $connectionState");
        if (connectionState == BluetoothConnectionState.disconnected) {
          _resetConnectionState();
          emit(
            state.copyWith(
              connectionState: connectionState,
              statusMessage: "Disconnected",
            ),
          );
        }
      });

      await _discoverServices(device);
    } on FlutterBluePlusException catch (e) {
      print("FlutterBluePlusException: ${e.description} (Code: ${e.code})");
      if (!isClosed) {
        emit(
          state.copyWith(
            isLoading: false,
            errorMessage: "Connection failed: ${e.description}",
          ),
        );
      }
    } catch (e, stacktrace) {
      print("General Exception: $e");
      print("Stacktrace: $stacktrace");
      if (!isClosed) {
        emit(
          state.copyWith(
            isLoading: false,
            errorMessage: "Connection failed: $e",
          ),
        );
      }
    } finally {
      print("Connection attempt finished.");
    }
  }

  // Remove Bond (Android Only)
  Future<void> removeBond() async {
    if (!Platform.isAndroid) {
      emit(
        state.copyWith(
          errorMessage: "Can only remove bond on Android for bonded devices.",
        ),
      );
      return;
    }
    emit(
      state.copyWith(
        isLoading: true,
        statusMessage: "Attempting to remove bond...",
      ),
    );
    try {
      await state.selectedDevice!.removeBond(); //
      // Bond state listener should update the state to 'none'
      emit(
        state.copyWith(isLoading: false, bondState: BluetoothBondState.none),
      ); // Clear loading after call
    } catch (e) {
      print("Remove Bond Error: $e");
      if (!isClosed) {
        emit(
          state.copyWith(
            isLoading: false,
            errorMessage: "Failed to remove bond: $e",
          ),
        );
      }
    }
  }

  Future<void> _subscribeToPicoBondStatus(BluetoothDevice device) async {
    if (_pairingStatusChar == null) {
      print(
        "[_subscribeToPicoBondStatus] Bond Status characteristic not found. Cannot subscribe.",
      );
      return; // Or handle error
    }
    if (!_pairingStatusChar!.properties.notify &&
        !_pairingStatusChar!.properties.read) {
      print(
        "[_subscribeToPicoBondStatus] Bond Status characteristic cannot be notified or read.",
      );
      print(
        '[_subscribeToPicoBondStatus] Properties: ${_pairingStatusChar!.properties}',
      );
      return; // Or handle error
    }

    // Prioritize Notify if available
    if (_pairingStatusChar!.properties.notify) {
      try {
        await _pairingStatusChar!.setNotifyValue(true);
        await _bondStatusValueSubscription?.cancel(); // Cancel previous if any
        _bondStatusValueSubscription = _pairingStatusChar!.onValueReceived
            .listen(
              (value) {
                if (value.isNotEmpty) {
                  bool picoReportsBonded =
                      value[0] == 1; // Assuming 1 means bonded
                  print("Pico Bonded Status: $picoReportsBonded");
                  if (!isClosed) {
                    emit(state.copyWith(isPicoBonded: picoReportsBonded));

                    if (!picoReportsBonded) {
                      emit(state.copyWith(bondState: BluetoothBondState.none));
                    } else {
                      emit(
                        state.copyWith(bondState: BluetoothBondState.bonded),
                      );
                    }
                  }
                }
              },
              onError: (error) {
                if (!isClosed) {
                  emit(state.copyWith(isPicoBonded: false)); // Reset on error
                }
              },
            );
        device.cancelWhenDisconnected(
          _bondStatusValueSubscription!,
        ); // Auto cancel

        // Optional: Read initial value after subscribing
        if (_pairingStatusChar!.properties.read) {
          await _readPicoBondStatus();
        }
      } catch (e) {
        print("[_subscribeToPicoBondStatus] Error subscribing: $e");
        // Fallback to reading if notify fails? Or just report error.
        if (!isClosed) {
          emit(
            state.copyWith(
              isPicoBonded: false,
              errorMessage: "Failed to monitor bond status",
            ),
          );
        }
      }
    } else if (_pairingStatusChar!.properties.read) {
      // Fallback: Read if notify not supported (less ideal)
      print(
        "[_subscribeToPicoBondStatus] Notify not supported, will read instead.",
      );
      await _readPicoBondStatus(); // Read initial status
      // You might need to periodically read it if not using notify
    }
  }

  // Helper to read the value (used if subscribing or reading directly)
  Future<void> _readPicoBondStatus() async {
    if (_pairingStatusChar == null || !_pairingStatusChar!.properties.read)
      return;
    try {
      print("[_readPicoBondStatus] Reading bond status...");
      final value = await _pairingStatusChar!.read();
      print("[_readPicoBondStatus] Read value: $value");
      if (value.isNotEmpty) {
        bool bonded = value[0] == 1;
        print("   Pico Bonded Status: $bonded");
        if (!isClosed) {
          emit(state.copyWith(isPicoBonded: bonded));
        }
      }
    } catch (e) {
      print("[_readPicoBondStatus] Error reading bond status: $e");
      if (!isClosed) {
        emit(state.copyWith(isPicoBonded: false)); // Reset on error
      }
    }
  }

  // Service Discovery, Characteristic Finding, Subscription, Sending Credentials
  Future<void> _discoverServices(BluetoothDevice device) async {
    try {
      List<BluetoothService> services = await device.discoverServices();
      _findCharacteristics(services);
      if ( //_statusChar != null &&
      _ssidChar != null && _passwordChar != null && _commandChar != null) {
        emit(
          state.copyWith(
            servicesDiscovered: true,
            isLoading: false,
            statusMessage: "Ready to send credentials.",
          ),
        );
        // await _subscribeToStatusUpdates(device);
        // print('[_discoverServices] Subscribed to status updates.');
        await _subscribeToPicoBondStatus(device); // Subscribe to bond status
      } else {
        emit(
          state.copyWith(
            servicesDiscovered: false,
            isLoading: false,
            errorMessage: "Required characteristics not found.",
          ),
        );
        await disconnectDevice();
      }
    } catch (e) {
      print("Discover Services Error: $e");
      if (!isClosed) {
        emit(
          state.copyWith(
            servicesDiscovered: false,
            isLoading: false,
            errorMessage: "Service Discovery failed: $e",
          ),
        );
        await disconnectDevice();
      }
    }
  }

  void _findCharacteristics(List<BluetoothService> services) {
    _ssidChar = null;
    _passwordChar = null;
    _commandChar = null;
    _pairingStatusChar = null;
    print(
      "[_findCharacteristics] Searching for characteristics in ${services.length} services...",
    );
    for (BluetoothService service in services) {
      print('Service UUID: ${service.uuid}');
      if (service.uuid == _serviceUuid) {
        for (BluetoothCharacteristic c in service.characteristics) {
          if (c.uuid == _ssidCharUuid) _ssidChar = c;
          if (c.uuid == _passwordCharUuid) _passwordChar = c;
          if (c.uuid == _commandCharUuid) _commandChar = c;
          if (c.uuid == _pairingStatusCharUuid) _pairingStatusChar = c;
        }
        // ... check if essential chars found ...
        if (_pairingStatusChar != null) {
          print("[_findCharacteristics] Found Bond Status characteristic.");
        } else {
          print("[_findCharacteristics] Bond Status characteristic NOT found.");
          // Decide if this is critical - if so, disconnect or show error
        }
        break;
      }
    }
  }

  Future<void> sendCredentials(
    String ssid,
    String password,
    bool saveNetwork,
  ) async {
    if (state.connectionState != BluetoothConnectionState.connected ||
        !state.servicesDiscovered) {
      emit(
        state.copyWith(
          errorMessage: "Not connected or services not discovered.",
        ),
      );
      return;
    }
    if (state.bondState != BluetoothBondState.bonded && !state.isPicoBonded) {
      // Check both OS bond state and Pico's reported bond status
      emit(
        state.copyWith(
          errorMessage: "Device not bonded. Cannot send credentials securely.",
        ),
      );
      return;
    }
    if (_ssidChar == null || _passwordChar == null || _commandChar == null) {
      emit(
        state.copyWith(errorMessage: "Characteristics not found. Cannot send."),
      );
      return;
    }
    emit(
      state.copyWith(
        isLoading: true,
        clearErrorMessage: true,
        statusMessage: "Sending credentials...",
      ),
    );
    try {
      List<int> ssidBytes = utf8.encode(ssid);
      List<int> passwordBytes = utf8.encode(password);

      // Write SSID and Password first
      await _ssidChar!.write(ssidBytes, withoutResponse: false);
      await _passwordChar!.write(passwordBytes, withoutResponse: false);
      print("SSID and Password written.");

      if (saveNetwork) {
        List<int> saveCommandBytes = [0x01]; // CMD_SAVE_NETWORK
        print("Sending CMD_SAVE_NETWORK (0x01) to Command Characteristic...");
        await _commandChar!.write(
          saveCommandBytes,
          withoutResponse:
              false, // Pico characteristic doesn't require response, but waiting for ack is safer
          timeout: 5, // Timeout for the write operation
        );
        print("CMD_SAVE_NETWORK sent.");
        // A small delay can sometimes be helpful for the peripheral to process, though not always necessary
        await Future.delayed(const Duration(milliseconds: 500));
      }

      List<int> connectCommandBytes = [0x02]; // CMD_CONNECT
      print("Sending CMD_CONNECT (0x02) to Command Characteristic...");
      try {
        await _commandChar!.write(
          connectCommandBytes,
          withoutResponse: false,
          timeout: 5,
        );
        print("CMD_CONNECT sent.");
      } on Exception catch (e) {
        // Even if this specific write isn't confirmed, the Pico might still process it.
        print('Command characteristic write for CMD_CONNECT not confirmed: $e');
      }

      emit(
        state.copyWith(
          isLoading: false,
          statusMessage:
              "Credentials sent. Pico attempting WiFi connection... BLE will disconnect.",
        ),
      );
      print('Credentials and command(s) sent.');
      print('BLE connection will likely be closed by peripheral.');
    } catch (e) {
      print('Error writing characteristics: $e');
      if (!isClosed) {
        emit(
          state.copyWith(
            isLoading: false,
            errorMessage: "Failed to send credentials: $e",
          ),
        );
      }
    }
  }

  /// Initiates disconnection from the currently selected device.
  Future<void> disconnectDevice() async {
    if (state.selectedDevice == null) {
      print("No device selected to disconnect.");
      return;
    }
    // Set loading or status message if desired
    // emit(state.copyWith(isLoading: true, statusMessage: "Disconnecting..."));
    try {
      await state.selectedDevice!.disconnect();
      print("Disconnect initiated for ${state.selectedDevice!.remoteId}");
      // The connection state listener (`_connectionStateSubscription`)
      // will automatically call `_resetConnectionState` when the
      // state becomes `disconnected`.
    } catch (e) {
      print("Disconnect Error: $e");
      if (!isClosed) {
        // Reset state even on error, potentially show error message
        _resetConnectionState();
        emit(
          state.copyWith(
            isLoading: false,
            errorMessage: "Disconnect failed: $e",
          ),
        );
      }
    }
  }

  // Cleanup
  void _resetConnectionState() {
    _ssidChar = null;
    _passwordChar = null;
    _commandChar = null;
    // removeBond();
    if (!isClosed) {
      emit(
        state.copyWith(
          connectionState: BluetoothConnectionState.disconnected,
          servicesDiscovered: false,
          isLoading: false,
        ),
      );
    }
  }

  @override
  Future<void> close() {
    _adapterStateSubscription?.cancel();
    _scanResultsSubscription?.cancel();
    _connectionStateSubscription?.cancel();
    _bondStatusValueSubscription?.cancel();
    state.selectedDevice?.disconnect();
    return super.close();
  }
}
