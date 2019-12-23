//
//  QuestionViewController.swift
//  testApp
//
//  Created by Colin J Power on 4/4/19.
//  Copyright © 2019 Colin Power. All rights reserved.
//

import UIKit
import Firebase
import FirebaseDatabase
import FirebaseFirestore

class QuestionViewController: UIViewController, UITableViewDelegate, UITextViewDelegate, UITableViewDataSource {
    
    
    // MARK: OUTLETS
    @IBOutlet weak var messagesTableView: UITableView!
    @IBOutlet weak var enterResponseField: UITextView!
    @IBOutlet weak var footerUIView: UIView!
    @IBOutlet weak var heightOfFooter: NSLayoutConstraint!
    @IBOutlet weak var distanceFromBottomOfFooterToSafeView: NSLayoutConstraint!
    
    
    
    // MARK: ACTIONS
    
    //the resolved button, which triggers the resolved modal vc
    @IBAction func resolveButton(_ sender: Any) {
        self.performSegue(withIdentifier: "segueToResolved", sender: nil)
    }
    
    //the read FAQ button, which pulls up the FAQ for this company
    @IBAction func readFAQsButton(_ sender: Any) {
        self.performSegue(withIdentifier: "segueToFAQs", sender: nil)
    }
    
    // the send button, which sends the message that the agent has typed
    @IBAction func sendButton(_ sender: Any) {
        let tempText = enterResponseField!.text
        let tempGUID = questionGUID!
        let tstamp = Int(NSDate().timeIntervalSince1970 * 1000)
        
        //send the message to the chats/tempGUID/messages collection as a new doc
    Firestore.firestore().collection("chats").document(tempGUID).collection("messages").document().setData(["message":tempText!, "timestamp":tstamp, "senderID":"Colin123"])
   
        //update the last message properties in the chat, so you know sender, timestamp, message
    Firestore.firestore().collection("chats").document(tempGUID).updateData(["lastUpdated":tstamp,"lastMessage":tempText!, "fromAgent":true])
        
        //update the question so that it's marked as answered, update lastMessageTime and lastMessageText
        Firestore.firestore().collection("questions").document(tempGUID).updateData(["agentID":"Colin123"])
        
        // reset the response field so that it's empty
        enterResponseField.text = ""
    }
    

    
    // MARK: VARIABLES

    var ref : DatabaseReference?
    var tempArr:[String:Any] = [:]
    var tempMessages:[String] = []
    var tempTimestamps:[Int] = []
    var tempSenders:[String] = []
    var holdsAllMessages = [[Any]]()
    var messages:[String] = ["test"]
    var mostRecentMessageTime:Int = 0
    
    //in order to pass data from the first VC, you need an optional value that you can set there.. so we'll set questionText there and it'll get passed here
    var questionText:String?
    var questionGUID:String?
    
    
    
    
    // MARK: VIEW DID LOAD
    
    override func viewDidLoad() {
        
        super.viewDidLoad()
        self.navigationItem.largeTitleDisplayMode = .never
        //        enterResponseField.becomeFirstResponder()
        
        // set up tableview so that the rows will resize
        self.messagesTableView.estimatedRowHeight = 44
        self.messagesTableView.rowHeight = UITableView.automaticDimension
        
        //resize the textview so that it's correct
        enterResponseField.delegate = self
        
        //set up the textfield
        enterResponseField.layer.borderColor = UIColor.gray.cgColor
        enterResponseField.layer.borderWidth = 0.5
        enterResponseField.layer.cornerRadius = 0.5
        
            
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow), name: UIResponder.keyboardWillShowNotification, object: nil)
        
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide), name: UIResponder.keyboardWillHideNotification, object: nil)
        
        getAllMessagesFirestore()
        
        scrollToBottom()
        
        //this should scroll the tableview to the bottom but it's not working??
        self.messagesTableView.setContentOffset(CGPoint(x: 0, y: CGFloat.greatestFiniteMagnitude), animated: false)
        
        self.messagesTableView.reloadData()
        
        //let heightOfTableView = tableViewHeight.constant
        
        
    }
    
    
    
    // MARK: HELPER FUNCTIONS

    func getAllMessagesFirestore() {
        
        //reconfiguring here
        
        // store tempGUID as the questionGUID passed from the first VC
        let tempGUID = questionGUID!
        
        //reference Firestore
        Firestore.firestore().collection("chats").document(tempGUID).collection("messages")
            .order(by: "timestamp")
            .addSnapshotListener { (data, error) in
            guard let snapshot = data else {
                print("Error fetching documents results: \(error!)")
                return
            }
            
            //clear holdsAllMessages when you get an update or on first load
            self.holdsAllMessages.removeAll()
            
            //loop through each entry in the snapshot
            for item in snapshot.documents {
                
                //need to get the DataSnapshot directly to get the right key
                let docID = item.documentID
                
                //need to get the array of the result
                let result = item.data() as! [String:Any]
                
                //create empty variable to save each question's data into
                var tempArray1:[Any] = []
                
                tempArray1.append(result["message"] as! String)
                tempArray1.append(result["timestamp"] as! Int)
                tempArray1.append(result["senderID"] as! String)
                self.holdsAllMessages.append(tempArray1)
                self.mostRecentMessageTime = result["timestamp"] as! Int
            }
            self.messagesTableView.reloadData()
        }
    }
    
    
    // converts timestamps to usable times
    func timestampToString(timestamp:Int) -> String {
        //compare current time to time of message
        let currentTime:Int = Int(NSDate().timeIntervalSince1970 * 1000)
        let dif:Int = currentTime - timestamp
        var stringForUser = ""
        var temp:Int = 0
        
        let monthMS = 2592000000
        let dayMS = 86400000
        let hourMS = 3600000
        let minuteMS = 60000
        
        if dif > monthMS {
            temp = dif/monthMS
            stringForUser = ("\(temp)mo ago")
        } else if dif > dayMS {
            temp = dif/dayMS
            stringForUser = ("\(temp)d ago")
        } else if dif > hourMS {
            temp = dif/hourMS
            stringForUser = ("\(temp)h ago")
        } else {
            temp = dif/minuteMS
            stringForUser = ("\(temp) min ago")
        }
        return stringForUser
    }
    
    
    
    // MARK: KEYBOARD RESPONDER
    
    deinit {
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillHideNotification, object: nil)
    }
    
  
    
    @objc func keyboardWillShow(notification: NSNotification) {
        guard let keyboardRect = (notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue else {
            return
        }
        
        distanceFromBottomOfFooterToSafeView.constant = -keyboardRect.height + 50

        //NOTE: can't figure out how to scroll to the right row.. this code doesn't currently do anything
        //reload data to fix any issues?
        messagesTableView.reloadData()
        
        //get index path of bottom row
        let indexPath = NSIndexPath(item: self.messagesTableView.numberOfRows(inSection: 0) - 1, section: 0)
        
        //scroll to bottom row using index path
        messagesTableView.scrollToRow(at: indexPath as IndexPath, at: UITableView.ScrollPosition.bottom, animated: true)
        
    }
    @objc func keyboardWillHide(notification: NSNotification) {
        distanceFromBottomOfFooterToSafeView.constant = 0
        //tableViewHeight.constant = 0
        
        //view.frame.origin.y = 0
        
        ///self.messagesTableView.contentInset = UIEdgeInsets(top: 0.0, left: 0.0, bottom: 0.0, right: 0.0)
        
    }
    
    
    func textViewDidChange(_ textView: UITextView) {
        let fixedWidth = textView.frame.size.width
        textView.sizeThatFits(CGSize(width: fixedWidth, height: CGFloat.greatestFiniteMagnitude))
        let newSize = textView.sizeThatFits(CGSize(width: fixedWidth, height: CGFloat.greatestFiniteMagnitude))
        var newFrame = textView.frame
        newFrame.size = CGSize(width: max(newSize.width, fixedWidth), height: newSize.height)
        textView.frame = newFrame
        
        heightOfFooter.constant = 62 + newSize.height
    }
    
    func textViewDidBeginEditing(_ textView: UITextView) {
        textView.text = ""
    }
    
    func scrollToBottom(){
//        DispatchQueue.main.async {
//            let indexPath = IndexPath(row: self.holdsAllMessages.count-1, section: 0)
//            self.messagesTableView.scrollToRow(at: indexPath, at: .bottom, animated: true)
//        }
    }
    
    
    
    // MARK: SEGUES
    
    //in preparing for segue, set the optional variable there to grab the question
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        //need to know destination of the segue... the segue variable contains that info
        //you use the variable questionVC to get an instance of the QuestionViewController class you just created
        print(segue.identifier as? String)
        if segue.identifier == "showConfirmationViewController" {
            let confirmationVC = segue.destination as! ConfirmationViewController
            confirmationVC.questionGUID = questionGUID
        } else if segue.identifier == "showSnippetVC" {
            print("here")
            let snippetVC = segue.destination as! SnippetVC
        }
//        else if segue.identifier == "showFAQViewController" {
//            print("segue-ing to faqs")
//            let faqvc = segue.destination as! FAQViewController
//        }
        else if segue.identifier == "signOutSegue" {
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        //when this view is going away, stop observing for changes to the thing we're observing above
        ref?.removeAllObservers()
    }
    
    
    
    // MARK: SET UP TABLEVIEW
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        //put if condition here that checks the row at indexPath

        if holdsAllMessages[indexPath.row][2] as! String == "Colin123" {
            //print("responseCell")
            let cell = tableView.dequeueReusableCell(withIdentifier: "responseCell", for: indexPath) as! ResponseCell
            
            //set labels for cell
            cell.responseLabel?.text = holdsAllMessages[indexPath.row][0] as? String
            cell.responseLabel?.numberOfLines = 0
            
            let string1 = timestampToString(timestamp: holdsAllMessages[indexPath.row][1] as! Int)
            cell.timestampLabel?.text = string1
            
            cell.selectionStyle = UITableViewCell.SelectionStyle.none
            
            return cell
            
        } else {
            //print("messagingCell")
            
            let cell = tableView.dequeueReusableCell(withIdentifier: "messagingCell", for: indexPath) as! MessageCell
            
            //set label for cell
            cell.messageLabel?.text = holdsAllMessages[indexPath.row][0] as? String
            cell.messageLabel?.numberOfLines = 0
            
            let string1 = timestampToString(timestamp: holdsAllMessages[indexPath.row][1] as! Int)
            cell.messageTimestamp?.text = string1
            
            cell.selectionStyle = UITableViewCell.SelectionStyle.none
            
            return cell
        }
        
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {        
        return holdsAllMessages.count
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return UITableView.automaticDimension
    }
    
}
