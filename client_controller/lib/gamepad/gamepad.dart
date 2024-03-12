import 'dart:ffi';

import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';

import 'gamepad_state.dart';

class Gamepad {
  Gamepad(this.controller) {
    _initializeCom();
    updateState();
  }

  /// Идентификатор текущего контроллера.
  ///
  /// К системе может быть подключено до четырех контроллеров, пронумерованных от '0' до '3'.
  final int controller;

  int _packetNumber = -1;

  /// Состояние кнопок, триггеров и джойстиков на геймпаде.
  late GamepadState state;

  /// Whether COM has been initialized.
  static bool _isComInitialized = false;

  void _initializeCom() {
    if (!_isComInitialized) {
      final hr = CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED | COINIT_DISABLE_OLE1DDE);
      if (FAILED(hr)) throw WindowsException(hr);
      _isComInitialized = true;
    }
  }

  /// Управляет активностью геймпада.
  ///
  /// Функция предназначена для вызова, когда приложение получает или теряет фокусировку. Когда
  /// установлено значение false, вызовы [updateState] возвращают нейтральные значения.
  set appHasFocus(bool value) => XInputEnable(value ? TRUE : FALSE);

  /// Получем текущее состояние выбранного контроллера.
  ///
  /// Функция предназначена для однократного вызова при каждом прохождении игрового цикла.
  /// Ее можно безопасно вызывать, даже если геймпад отключен, при этом
  /// для всех кнопок и джойстиков будут возвращены нейтральные значения.
  void updateState() {
    final pState = calloc<XINPUT_STATE>();
    try {
      final dwResult = XInputGetState(controller, pState);
      if (dwResult == ERROR_SUCCESS) {
        final XINPUT_STATE(:dwPacketNumber, Gamepad: gamepad) = pState.ref;
        // Если возвращаемый структурой XINPUT_STATE, элемент dwPacketNumber тот же самый,
        // то состояние контроллера не изменилось, поэтому выходим.
        if (dwPacketNumber == _packetNumber) return;

        _packetNumber = dwPacketNumber;
        state = GamepadState(
          true,
          gamepad.wButtons,
          gamepad.bLeftTrigger,
          gamepad.bRightTrigger,
          gamepad.sThumbLX,
          gamepad.sThumbLY,
          gamepad.sThumbRX,
          gamepad.sThumbRY,
        );
      } else if (dwResult == ERROR_DEVICE_NOT_CONNECTED) {
        state = GamepadState.disconnected();
      } else {
        throw WindowsException(dwResult);
      }
    } finally {
      free(pState);
    }
  }

  /// Возвращает значение, указывающее, подключен ли контроллер.
  ///
  /// Это можно использовать для определения того, какие контроллеры подключены к системе.
  /// Но контроллер может быть отключен в любой момент, поэтому значение true
  /// не гарантирует, что следующий вызов будет успешным. Вместо этого guard вызывает
  /// другие функции, чтобы проверить, что [DeviceNotConnectedError] не генерируется.
  bool get isConnected => state.isConnected;
}
