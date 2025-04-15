import Flutter
import UIKit
import ContactsUI

public class FlutterNativeContactPickerPlugin: NSObject, FlutterPlugin {
  var _delegate: PickerHandler?;

  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "flutter_native_contact_picker", binaryMessenger: registrar.messenger())
    let instance = FlutterNativeContactPickerPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    if call.method == "selectContact" || call.method == "selectContacts" || call.method == "selectPhoneNumber" {
        if _delegate != nil {
            _delegate!.result(FlutterError(code: "multiple_requests", message: "Cancelled by a second request.", details: nil))
            _delegate = nil
        }

        if #available(iOS 9.0, *) {
            let isSelectContact = call.method == "selectContact"
            let isSelectPhoneNumber = call.method == "selectPhoneNumber"
            let isMultiSelect = call.method == "selectContacts"
            
            let contactPicker = CNContactPickerViewController()
            
            if isSelectContact || isSelectPhoneNumber {
                _delegate = PhoneNumberPickerHandler(result: result)
                contactPicker.displayedPropertyKeys = [CNContactPhoneNumbersKey]
            } else if isMultiSelect {
                _delegate = MultiPickerHandler(result: result)
                contactPicker.displayedPropertyKeys = nil
            }
            
            contactPicker.delegate = _delegate
            
            // Find proper keyWindow
            var keyWindow: UIWindow? = nil
            if #available(iOS 13, *) {
                keyWindow = UIApplication.shared.connectedScenes
                    .filter { $0.activationState == .foregroundActive }
                    .compactMap { $0 as? UIWindowScene }
                    .first?.windows
                    .filter { $0.isKeyWindow }
                    .first
            } else {
                keyWindow = UIApplication.shared.keyWindow
            }
            
            keyWindow?.rootViewController?.present(contactPicker, animated: true, completion: nil)
        }
    } else {
        result(FlutterMethodNotImplemented)
    }
  }
}

class PickerHandler: NSObject, CNContactPickerDelegate {
    var result: FlutterResult
    
    required init(result: @escaping FlutterResult) {
        self.result = result
        super.init()
    }
    
    @available(iOS 9.0, *)
    public func contactPickerDidCancel(_ picker: CNContactPickerViewController) {
        result(nil)
    }
}

class MultiPickerHandler: PickerHandler {
    @available(iOS 9.0, *)
    public func contactPicker(_ picker: CNContactPickerViewController, didSelect contacts: [CNContact]) {
        var selectedContacts = [[String: Any]]()
        for contact in contacts {
            var contactInfo = [String: Any]()
            contactInfo["fullName"] = CNContactFormatter.string(from: contact, style: .fullName)
            let numbers = contact.phoneNumbers.compactMap { $0.value.stringValue }
            contactInfo["phoneNumbers"] = numbers
            selectedContacts.append(contactInfo)
        }
        result(selectedContacts)
    }
}

class PhoneNumberPickerHandler: PickerHandler {
    @available(iOS 9.0, *)
    public func contactPicker(_ picker: CNContactPickerViewController, didSelect contactProperty: CNContactProperty) {
        guard contactProperty.key == CNContactPhoneNumbersKey,
              let phoneNumber = contactProperty.value as? CNPhoneNumber else {
            result(FlutterError(code: "invalid_selection", message: "Selected property is not a phone number", details: nil))
            return
        }
        
        let contact = contactProperty.contact
        
        let fullName = CNContactFormatter.string(from: contact, style: .fullName)
        let allNumbers = contact.phoneNumbers.compactMap { $0.value.stringValue }
        let selectedNumber = phoneNumber.stringValue
        
        let resultData: [String: Any] = [
            "fullName": fullName ?? "",
            "selectedPhoneNumber": selectedNumber,
            "phoneNumbers": allNumbers
        ]
        
        result(resultData)
    }
}