//
//  CreatePostViewController.swift
//  CS490RSharing
//
//  Created by Jonathan G. Dzialo on 2/13/19.
//  Copyright © 2019 Group6. All rights reserved.
//

import UIKit
import FirebaseDatabase
import FirebaseFirestore
import FirebaseAuth
import FirebaseStorage
import UserNotifications



class CreatePostViewController: UIViewController,UNUserNotificationCenterDelegate,UIPickerViewDelegate,UIPickerViewDataSource {

    @IBOutlet weak var foodImageView: UIImageView!
    var imagePicker = UIImagePickerController()
    var refPosts: DatabaseReference!
    private let db = Firestore.firestore()
    private let storage = Storage.storage().reference()
    var foodImage: UIImage!
    @IBOutlet weak var foodLocationTextField: UITextField!
    @IBOutlet weak var foodTypeTextField: UITextField!
    @IBOutlet weak var foodQuantityTextField: UITextField!
    @IBOutlet weak var notesTextField: UITextView!
    @IBOutlet weak var SubmitPostButton: UIButton!
    private var channelReference: CollectionReference {
        return db.collection("channels")
    }
    private var imageReference: StorageReference{
        return Storage.storage().reference().child("Images")
    }
    private var channels = [Channel]()
    //private var channelListener: ListenerRegistration?
    private let currentUser = Auth.auth().currentUser
    let pickerData = [String](arrayLiteral: "Small (1-19)","Medium (20-49)","Large (50+)" )
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }
    
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return pickerData.count
    }
    
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        return pickerData[row]
    }
    
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        foodQuantityTextField.text = pickerData[row]
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.hideKeyboardWhenTappedAround()
        SubmitPostButton.isEnabled = false
        self.title = "Create Post"
        
        refPosts = Database.database().reference().child("Posts")
        
        imagePicker.delegate = self
        
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert]) {
            (granted, error) in
            if granted {
                print("yes")
            } else {
                print("No")
            }
        }
        
        let picker = UIPickerView()
        picker.delegate=self
        foodQuantityTextField.inputView = picker
    }//end ViewDidLoad()
    
    @objc func textChanged(sender:NSNotification){
        if (foodImageView.image == nil){SubmitPostButton.isEnabled=false}
        else {SubmitPostButton.isEnabled = true}
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    @IBAction func createPost(_ sender: Any) {
        addPost()
        createChannel()
        sendNotification()
        if(self.foodImageView.image == nil){
            print("no image")
        }else{
            addImagetoStorage()
        }
        print("Post added!")
        
        foodLocationTextField.text = ""
        foodTypeTextField.text = ""
        foodQuantityTextField.text = ""
        notesTextField.text = ""
        foodImageView.image = nil
        
        ToastView.shared.long(self.view, txt_msg: "Post Created!")
        //Timer.scheduledTimer(timeInterval: 3, target: self, selector:#selector(CreatePostViewController.delayPostCreation), userInfo: nil, repeats: false)
        //let vc = self.storyboard?.instantiateViewController(withIdentifier: "AllPostsTableViewController")
        //self.navigationController?.pushViewController(vc!, animated: true)
    }
    
    @objc func delayPostCreation(){
        let vc = self.storyboard?.instantiateViewController(withIdentifier: "AllPostsTableViewController")
        self.navigationController?.pushViewController(vc!, animated: true)
    }
    
    @IBAction func chooseFromCameraRoll(_ sender: Any) {
        imagePicker.sourceType = .photoLibrary
        imagePicker.allowsEditing = false
        present(imagePicker, animated: true, completion: nil)
    }
    
    @IBAction func takePhoto(_ sender: Any) {
        imagePicker.delegate = self
        imagePicker.sourceType = .camera
        
        present(imagePicker, animated: true, completion: nil)
    }
    
    func addPost(){
        let currentDateTime = Date()
        let formatter = DateFormatter()
        formatter.timeStyle = .medium
        formatter.dateStyle = .medium
        let time = formatter.string(from: currentDateTime)
        let endTime = formatter.string(from: currentDateTime.addingTimeInterval(15))
        let key = refPosts.childByAutoId().key
        let userID = Auth.auth().currentUser!.uid
        let group = ["location": foodLocationTextField.text! as String,
                     "time": time,
                     "endTime": endTime,
                     "id":key!,
                     "type": foodTypeTextField.text! as String,
                     "quantity": foodQuantityTextField.text! as String,
                     "notes": notesTextField.text! as String,
                     "userID": userID as String]
        refPosts.child(key!).setValue(group)
    }
    
    private func createChannel() {
        guard let channelName = foodLocationTextField.text else {
            return
        }
        
        let channel = Channel(id: "",name: channelName)
        channelReference.addDocument(data: channel.representation) { error in
            if let e = error {
                print("Error saving channel: \(e.localizedDescription)")
            }else{
                print("Document Added")
            }
        }
    }//end CreateChannel()
    
    private func sendNotification(){
        let content = UNMutableNotificationContent()
        content.title = foodLocationTextField.text!
        content.subtitle = foodTypeTextField.text!
        content.body = foodQuantityTextField.text!
        content.badge = 1
        
        let imageName = "newmessage"
        guard let imageURL = Bundle.main.url(forResource: imageName, withExtension: "png") else {
            print("no image")
            return }
        
        let attachment = try! UNNotificationAttachment(identifier: imageName, url: imageURL, options: .none)
        content.attachments = [attachment]
        
       
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 10, repeats: false)
        let request = UNNotificationRequest(identifier: "notification.id.01", content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().delegate = self
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
    }
    
    private func addImagetoStorage(){
        let userID = Auth.auth().currentUser!.uid
        let imageRef = storage.child("Images/" + userID + foodTypeTextField.text! + ".jpeg")
        let metaData = StorageMetadata()
        metaData.contentType = "image/jpeg"
        imageRef.putData(foodImage.jpegData(compressionQuality: 0.8)!,metadata:metaData) { (data,error) in
            if error == nil{
                print("image upload successful")
            }
            else{
                print(error?.localizedDescription)
            }
        }
    }
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        
        //displaying the ios local notification when app is in foreground
        completionHandler([.alert, .badge, .sound])
    }
}

extension CreatePostViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate{
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        if let image = info[UIImagePickerController.InfoKey.originalImage] as? UIImage{
            foodImageView.image = image
            foodImage = image
            
            /*
            let imageRef = storage.child("Images/image.jpeg")
            let metaData = StorageMetadata()
            metaData.contentType = "image/jpeg"
            imageRef.putData(image.jpegData(compressionQuality: 0.8)!,metadata:metaData) { (data,error) in
                if error == nil{
                    print("image upload successful")
                }
                else{
                    print(error?.localizedDescription)
                }
            }
             */
        }
        dismiss(animated: true, completion: nil)
        SubmitPostButton.isEnabled=true
    }
}

extension UIViewController {
    func hideKeyboardWhenTappedAround() {
        let tap: UITapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(UIViewController.dismissKeyboard))
        tap.cancelsTouchesInView = false
        view.addGestureRecognizer(tap)
    }
    
    @objc func dismissKeyboard() {
        view.endEditing(true)
    }
}
