import 'package:win32/win32.dart';

class GamepadState {
  final int _buttonBitmask;

  /// Возвращает true, если геймпад в данный момент подключен.
  final bool isConnected;

  /// Текущие значения аналоговых регуляторов левого / правого триггера.
  /// Значение находится в диапазоне от 0 до 255.
  final int leftTrigger;
  final int rightTrigger;

  /// Значения осей левого / правого джойстика.
  ///
  /// Значение со знаком от -32768 до 32767. Значение 0 находится по центру.
  /// Отрицательное значение указывают на движенрие влево или вниз.
  /// Положительное значения указывают на движенрие вправо или вверх.
  /// Постоянное значение [GamepadCapabilities.leftThumbDeadzone] может использоваться в качестве положительного и
  /// отрицательного фильтра для фильтрации ввода с помощью джойстика.
  final int leftThumbstickX;
  final int leftThumbstickY;
  final int rightThumbstickX;
  final int rightThumbstickY;

  const GamepadState(
    this.isConnected,
    this._buttonBitmask,
    this.leftTrigger,
    this.rightTrigger,
    this.leftThumbstickX,
    this.leftThumbstickY,
    this.rightThumbstickX,
    this.rightThumbstickY,
  );

  /// Gamepad отключен.
  factory GamepadState.disconnected() => const GamepadState(false, 0, 0, 0, 0, 0, 0, 0);

  /// Возвращает восьмиступенчатое направление, при нажатии на крестовину,
  /// или [Direction.center], если d-pad не нажат.
  Direction get dpadDirection {
    if (dpadLeft && dpadUp) return Direction.northwest;
    if (dpadLeft && dpadDown) return Direction.southwest;
    if (dpadLeft) return Direction.west;
    if (dpadRight && dpadUp) return Direction.northeast;
    if (dpadRight && dpadDown) return Direction.southeast;
    if (dpadRight) return Direction.east;
    if (dpadUp) return Direction.north;
    if (dpadDown) return Direction.south;
    return Direction.center;
  }

  /// Возвращает значение true, если направление D-pad вверх.
  bool get dpadUp => _buttonBitmask & XINPUT_GAMEPAD_DPAD_UP == XINPUT_GAMEPAD_DPAD_UP;

  /// Возвращает значение true, если направление D-pad направлено вниз.
  bool get dpadDown => _buttonBitmask & XINPUT_GAMEPAD_DPAD_DOWN == XINPUT_GAMEPAD_DPAD_DOWN;

  /// Возвращает значение true, если направление D-pad левое.
  bool get dpadLeft => _buttonBitmask & XINPUT_GAMEPAD_DPAD_LEFT == XINPUT_GAMEPAD_DPAD_LEFT;

  /// Возвращает значение true, если направление D-pad правое.
  bool get dpadRight => _buttonBitmask & XINPUT_GAMEPAD_DPAD_RIGHT == XINPUT_GAMEPAD_DPAD_RIGHT;

  /// Возвращает значение true, если кнопка "Start" нажата.
  bool get buttonStart => _buttonBitmask & XINPUT_GAMEPAD_START == XINPUT_GAMEPAD_START;

  /// Возвращает значение true, если кнопка "Back" нажата.
  bool get buttonBack => _buttonBitmask & XINPUT_GAMEPAD_BACK == XINPUT_GAMEPAD_BACK;

  /// Возвращает значение true при нажатии на левый стик.
  bool get leftThumb => _buttonBitmask & XINPUT_GAMEPAD_LEFT_THUMB == XINPUT_GAMEPAD_LEFT_THUMB;

  /// Возвращает значение true при нажатии на правый стик.
  bool get rightThumb => _buttonBitmask & XINPUT_GAMEPAD_RIGHT_THUMB == XINPUT_GAMEPAD_RIGHT_THUMB;

  /// Возвращает значение true, если нажата кнопка L1.
  bool get leftShoulder => _buttonBitmask & XINPUT_GAMEPAD_LEFT_SHOULDER == XINPUT_GAMEPAD_LEFT_SHOULDER;

  /// Возвращает значение true, если нажата кнопка R1.
  bool get rightShoulder =>
      _buttonBitmask & XINPUT_GAMEPAD_RIGHT_SHOULDER == XINPUT_GAMEPAD_RIGHT_SHOULDER;

  /// Возвращает значение true, если кнопка A нажата.
  bool get buttonA => _buttonBitmask & XINPUT_GAMEPAD_A == XINPUT_GAMEPAD_A;

  /// Возвращает значение true, если кнопка B нажата.
  bool get buttonB => _buttonBitmask & XINPUT_GAMEPAD_B == XINPUT_GAMEPAD_B;

  /// Возвращает значение true, если кнопка X нажата.
  bool get buttonX => _buttonBitmask & XINPUT_GAMEPAD_X == XINPUT_GAMEPAD_X;

  /// Возвращает значение true, если кнопка Y нажата.
  bool get buttonY => _buttonBitmask & XINPUT_GAMEPAD_Y == XINPUT_GAMEPAD_Y;
}

enum Direction {
  /// Left.
  west,

  /// Left and up.
  northwest,

  /// Up.
  north,

  /// Up and right.
  northeast,

  /// Right.
  east,

  /// Down and right.
  southeast,

  /// Down.
  south,

  /// Down and left.
  southwest,

  /// Neutral (not pressed).
  center
}
