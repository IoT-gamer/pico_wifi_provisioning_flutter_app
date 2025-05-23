part of 'ble_cubit.dart';

class BleState extends Equatable {
  final BluetoothAdapterState adapterState;
  final bool isScanning;
  final List<ScanResult> scanResults;
  final BluetoothDevice? selectedDevice;
  final BluetoothConnectionState connectionState;
  final BluetoothBondState bondState;
  final bool isPicoBonded;
  final bool servicesDiscovered;
  final String? statusMessage;
  final String? errorMessage;
  final bool isLoading;

  const BleState({
    this.adapterState = BluetoothAdapterState.unknown,
    this.isScanning = false,
    this.scanResults = const [],
    this.selectedDevice,
    this.connectionState = BluetoothConnectionState.disconnected,
    this.bondState = BluetoothBondState.none,
    this.isPicoBonded = false,
    this.servicesDiscovered = false,
    this.statusMessage,
    this.errorMessage,
    this.isLoading = false,
  });

  BleState copyWith({
    BluetoothAdapterState? adapterState,
    bool? isScanning,
    List<ScanResult>? scanResults,
    BluetoothDevice? selectedDevice,
    bool clearSelectedDevice = false,
    BluetoothConnectionState? connectionState,
    BluetoothBondState? bondState,
    bool? isPicoBonded,
    bool? servicesDiscovered,
    String? statusMessage,
    bool clearStatusMessage = false,
    String? errorMessage,
    bool clearErrorMessage = false,
    bool? isLoading,
  }) {
    return BleState(
      adapterState: adapterState ?? this.adapterState,
      isScanning: isScanning ?? this.isScanning,
      scanResults: scanResults ?? this.scanResults,
      selectedDevice:
          clearSelectedDevice ? null : (selectedDevice ?? this.selectedDevice),
      connectionState: connectionState ?? this.connectionState,
      bondState: bondState ?? this.bondState,
      isPicoBonded: isPicoBonded ?? this.isPicoBonded,
      servicesDiscovered: servicesDiscovered ?? this.servicesDiscovered,

      statusMessage:
          clearStatusMessage ? null : (statusMessage ?? this.statusMessage),
      errorMessage:
          clearErrorMessage ? null : (errorMessage ?? this.errorMessage),
      isLoading: isLoading ?? this.isLoading,
    );
  }

  @override
  List<Object?> get props => [
    adapterState,
    isScanning,
    scanResults,
    selectedDevice,
    connectionState,
    bondState,
    isPicoBonded,
    servicesDiscovered,
    statusMessage,
    errorMessage,
    isLoading,
  ];
}
