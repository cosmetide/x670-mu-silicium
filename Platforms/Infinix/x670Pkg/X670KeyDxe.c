// SPDX-License-Identifier: BSD-2-Clause-Patent
// X670 keypad matrix: volume up = Up, volume down = Down, power = Enter.
#include <Uefi.h>
#include <Configuration/BootDevices.h>
#include <Protocol/SimpleTextIn.h>
#include <Protocol/SimpleTextInEx.h>
#include <Protocol/DevicePath.h>
#include <Library/BaseMemoryLib.h>
#include <Library/DebugLib.h>
#include <Library/IoLib.h>
#include <Library/UefiBootServicesTableLib.h>

#define KPD_BASE       0x10010000U
#define KPD_MEM1       0x004U
#define KPD_DEBOUNCE   0x018U
#define KPD_SEL        0x020U
#define KPD_EN         0x024U
#define KEY_VOL_UP     BIT0
#define KEY_VOL_DOWN   BIT1
#define KEY_POWER      BIT8

STATIC EFI_SIMPLE_TEXT_INPUT_PROTOCOL mInput;
STATIC EFI_SIMPLE_TEXT_INPUT_EX_PROTOCOL mInputEx;
STATIC EFI_EVENT mWaitEvent;
STATIC EFI_EVENT mWaitEventEx;
STATIC EFI_EVENT mPollEvent;
STATIC EFI_INPUT_KEY mKey;
STATIC EFI_KEY_DATA mKeyData;
STATIC EFI_KEY_DATA mNotifyKey;
STATIC EFI_KEY_NOTIFY_FUNCTION mNotifyFunction;
STATIC VOID *mNotifyHandle;
STATIC BOOLEAN mKeyReady;
STATIC UINT16 mKeysDown;

STATIC EFI_STATUS EFIAPI X670Reset (EFI_SIMPLE_TEXT_INPUT_PROTOCOL *This, BOOLEAN ExtendedVerification)
{
  mKeyReady = FALSE;
  mKeysDown = 0;
  return EFI_SUCCESS;
}

STATIC EFI_STATUS EFIAPI X670ReadKey (EFI_SIMPLE_TEXT_INPUT_PROTOCOL *This, EFI_INPUT_KEY *Key)
{
  if ((This == NULL) || (Key == NULL)) return EFI_INVALID_PARAMETER;
  if (!mKeyReady) return EFI_NOT_READY;
  *Key = mKey;
  mKeyReady = FALSE;
  return EFI_SUCCESS;
}

STATIC EFI_STATUS EFIAPI X670ReadKeyEx (EFI_SIMPLE_TEXT_INPUT_EX_PROTOCOL *This, EFI_KEY_DATA *KeyData)
{
  if ((This == NULL) || (KeyData == NULL)) return EFI_INVALID_PARAMETER;
  if (!mKeyReady) return EFI_NOT_READY;
  *KeyData = mKeyData;
  mKeyReady = FALSE;
  return EFI_SUCCESS;
}

STATIC EFI_STATUS EFIAPI X670ResetEx (EFI_SIMPLE_TEXT_INPUT_EX_PROTOCOL *This, BOOLEAN ExtendedVerification)
{
  return X670Reset (&mInput, ExtendedVerification);
}

STATIC EFI_STATUS EFIAPI X670SetState (EFI_SIMPLE_TEXT_INPUT_EX_PROTOCOL *This, EFI_KEY_TOGGLE_STATE *KeyToggleState)
{
  return EFI_UNSUPPORTED;
}

STATIC EFI_STATUS EFIAPI X670RegisterKeyNotify (
  EFI_SIMPLE_TEXT_INPUT_EX_PROTOCOL *This,
  EFI_KEY_DATA *KeyData,
  EFI_KEY_NOTIFY_FUNCTION KeyNotificationFunction,
  VOID **NotifyHandle
  )
{
  if ((KeyData == NULL) || (KeyNotificationFunction == NULL) || (NotifyHandle == NULL)) {
    return EFI_INVALID_PARAMETER;
  }
  if (mNotifyFunction != NULL) return EFI_ALREADY_STARTED;
  mNotifyKey = *KeyData;
  mNotifyFunction = KeyNotificationFunction;
  mNotifyHandle = &mNotifyFunction;
  *NotifyHandle = mNotifyHandle;
  return EFI_SUCCESS;
}

STATIC EFI_STATUS EFIAPI X670UnregisterKeyNotify (
  EFI_SIMPLE_TEXT_INPUT_EX_PROTOCOL *This,
  VOID *NotifyHandle
  )
{
  if ((mNotifyFunction == NULL) || (NotifyHandle != mNotifyHandle)) return EFI_INVALID_PARAMETER;
  mNotifyFunction = NULL;
  mNotifyHandle = NULL;
  ZeroMem (&mNotifyKey, sizeof (mNotifyKey));
  return EFI_SUCCESS;
}

STATIC VOID EFIAPI X670PollKeys (EFI_EVENT Event, VOID *Context)
{
  UINT16 Down = (UINT16)~MmioRead32 (KPD_BASE + KPD_MEM1);
  UINT16 Watched = KEY_VOL_UP | KEY_VOL_DOWN | KEY_POWER;
  UINT16 Pressed = (Down & Watched) & (UINT16)~mKeysDown;
  mKeysDown = Down & Watched;
  if (mKeyReady || (Pressed == 0)) return;

  if (Pressed & KEY_VOL_UP) {
    mKey.ScanCode = SCAN_UP;
    mKey.UnicodeChar = 0;
  } else if (Pressed & KEY_VOL_DOWN) {
    mKey.ScanCode = SCAN_DOWN;
    mKey.UnicodeChar = 0;
  } else {
    mKey.ScanCode = SCAN_NULL;
    mKey.UnicodeChar = CHAR_CARRIAGE_RETURN;
  }
  mKeyData.Key = mKey;
  mKeyData.KeyState.KeyShiftState = 0;
  mKeyData.KeyState.KeyToggleState = 0;
  mKeyReady = TRUE;
  if ((mNotifyFunction != NULL) &&
      (mNotifyKey.Key.ScanCode == mKeyData.Key.ScanCode) &&
      (mNotifyKey.Key.UnicodeChar == mKeyData.Key.UnicodeChar)) {
    mNotifyFunction (&mKeyData);
  }
  gBS->SignalEvent (mWaitEvent);
  gBS->SignalEvent (mWaitEventEx);
}

STATIC VOID EFIAPI X670WaitForKey (EFI_EVENT Event, VOID *Context)
{
  X670PollKeys (Event, Context);
}

EFI_STATUS EFIAPI X670KeyDxeEntryPoint (EFI_HANDLE ImageHandle, EFI_SYSTEM_TABLE *SystemTable)
{
  EFI_STATUS Status;
  DEBUG ((DEBUG_INFO, "X670 keys: volume up=Up, volume down=Down, power=Enter\n"));
  MmioWrite32 (KPD_BASE + KPD_DEBOUNCE, 0x400);
  MmioWrite32 (KPD_BASE + KPD_SEL, 0);
  MmioWrite32 (KPD_BASE + KPD_EN, BIT0);

  mInput.Reset = X670Reset;
  mInput.ReadKeyStroke = X670ReadKey;
  mInputEx.Reset = X670ResetEx;
  mInputEx.ReadKeyStrokeEx = X670ReadKeyEx;
  mInputEx.SetState = X670SetState;
  mInputEx.RegisterKeyNotify = X670RegisterKeyNotify;
  mInputEx.UnregisterKeyNotify = X670UnregisterKeyNotify;
  Status = gBS->CreateEvent (EVT_NOTIFY_WAIT, TPL_CALLBACK, X670WaitForKey, NULL, &mWaitEvent);
  if (EFI_ERROR (Status)) return Status;
  mInput.WaitForKey = mWaitEvent;
  Status = gBS->CreateEvent (EVT_NOTIFY_WAIT, TPL_CALLBACK, X670WaitForKey, NULL, &mWaitEventEx);
  if (EFI_ERROR (Status)) return Status;
  mInputEx.WaitForKeyEx = mWaitEventEx;
  Status = gBS->CreateEvent (EVT_TIMER | EVT_NOTIFY_SIGNAL, TPL_CALLBACK, X670PollKeys, NULL, &mPollEvent);
  if (EFI_ERROR (Status)) return Status;
  Status = gBS->SetTimer (mPollEvent, TimerPeriodic, 200000);
  if (EFI_ERROR (Status)) return Status;
  return gBS->InstallMultipleProtocolInterfaces (
           &ImageHandle,
           &gEfiSimpleTextInProtocolGuid,
           &mInput,
           &gEfiSimpleTextInputExProtocolGuid,
           &mInputEx,
           &gEfiDevicePathProtocolGuid,
           &KeypadDevicePath,
           NULL
           );
}
