//  AllPostsTableViewController.swift
//  CS490RSharing

import UIKit
import FirebaseDatabase
import FirebaseStorage

var selectedPost: Posts?
class AllPostsTableViewController: UITableViewController,UIViewControllerPreviewingDelegate {
    
    //3D Touch
    func previewingContext(_ previewingContext: UIViewControllerPreviewing, viewControllerForLocation location: CGPoint) -> UIViewController? {
        // First, get the index path and view for the previewed cell.
        guard let indexPath = tableView.indexPathForRow(at: location),
            let cell = tableView.cellForRow(at: indexPath)
            else { return nil }
        
        // Enable blurring of other UI elements, and a zoom in animation while peeking.
        previewingContext.sourceRect = cell.frame
        
        // Create and configure an instance of the color item view controller to show for the peek.
        guard let viewController = storyboard?.instantiateViewController(withIdentifier: "DetailViewController") as? DetailViewController
            else { preconditionFailure("Expected a ColorItemViewController") }
        
        // Pass over a reference to the ColorData object and the specific ColorItem being viewed.
        //viewController.colorData = colorData
        //viewController.colorItem = colorData.colors[indexPath.row]
        
        return viewController
    }
    
    func previewingContext(_ previewingContext: UIViewControllerPreviewing, commit DetailViewController: UIViewController) {
        show(DetailViewController,sender: self)
    }
    
    var ref: DatabaseReference!
    var currentPosts = [Posts]()
    var reversePosts = [Posts]()
    var removedIndex: Int = 0
    
    //Refresh
    lazy var rControl: UIRefreshControl = {
        let refreshControl = UIRefreshControl()
        refreshControl.addTarget(self, action:
            #selector(AllPostsTableViewController.handleRefresh(_:)),
                                 for: UIControl.Event.valueChanged)
        refreshControl.tintColor = UIColor.blue
        return refreshControl
    }()
    @objc func handleRefresh(_ refreshControl: UIRefreshControl) {
        deleteOldPosts()
        refreshControl.endRefreshing()
    }
    override func viewDidLoad() {
        super.viewDidLoad()
        self.tableView.reloadData()
        navigationItem.title = "Home"
        ref = Database.database().reference()
        print("All Posts view loaded")
        fetchPosts()
        deleteOldPosts()
        if (traitCollection.forceTouchCapability == UIForceTouchCapability.available){
            registerForPreviewing(with: self, sourceView: tableView)
        }
        else{ print("Failed") }
        
        self.tableView.addSubview(self.rControl)
        tableView.dataSource = self
    }//end viewDidLoad()
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    // MARK: - Table view data source
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        // #warning Incomplete implementation, return the number of sections
        return 1
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // #warning Incomplete implementation, return the number of rows
        return currentPosts.count
    }
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        selectedPost = reversePosts[indexPath.row]
        performSegue(withIdentifier: "descSegue", sender: self)
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if(indexPath.row > reversePosts.count - 1){
            return UITableViewCell()
        }else{
            let cell = tableView.dequeueReusableCell(withIdentifier: "postCell", for: indexPath)
            let eachPost = reversePosts[indexPath.row]
            
            //Populate tableView with post content
            cell.textLabel?.numberOfLines = 6
            cell.textLabel?.lineBreakMode = .byWordWrapping
            cell.textLabel?.textAlignment = .left
            cell.textLabel?.text = "Post Location: \(eachPost.location ?? "Location")\nFood Quantity: \(eachPost.quantity ?? "quantity")\nTime: \(eachPost.time ?? "Time") \nExpires: \(eachPost.endTime ?? "12:00")\nType: \(eachPost.type ?? "Type")"
            cell.textLabel?.textColor = UIColor.black
            let storageRef = Storage.storage().reference()
            let picRef = storageRef.child("Images/" + reversePosts[indexPath.row].userID! + reversePosts[indexPath.row].type! + ".jpeg")
            picRef.getData(maxSize: 1 * 2048 * 2048) { data, error in
                if let error = error {
                    print(error.localizedDescription)
                } else {
                    let image = UIImage(data: data!)
                    let cellImg : UIImageView = UIImageView(frame: CGRect(x: 300, y: 0, width: 115, height: 125))
                    cellImg.layer.cornerRadius = 20.0;
                    cellImg.layer.masksToBounds = true;
                    cellImg.image = image
                    cell.addSubview(cellImg)
                }
            }
            return cell
        }
    }//end tableView override function

    func fetchPosts(){
        Database.database().reference().child("Posts").observe(.childAdded, with: {  (snapshot) in
            if let dictionary = snapshot.value as? [String : AnyObject]{
                let posts = Posts()
                posts.setValuesForKeys(dictionary)
                self.currentPosts.append(posts)
                self.reversePosts = self.currentPosts.reversed()
                print("Reverse Posts length in FETCH: \(self.reversePosts.count)")
                DispatchQueue.main.async(execute: {
                    self.tableView.reloadData()
                })
            }
        })
    }
    
    func deleteOldPosts(){
        for posts in reversePosts{
            let postDate = posts.time
            let dateformatter = DateFormatter()
            dateformatter.timeStyle = .medium
            dateformatter.dateStyle = .medium
            let timeComparable = dateformatter.date(from: postDate!)
            let currentTime = Date()
            //delete post on refresh
            if(currentTime > (timeComparable?.addingTimeInterval(15))!){
                print("expired")
                ref.child("Posts").child(posts.id!).removeValue()
                let storage = Storage.storage().reference()
                let imageRef = storage.child("Images/" + posts.userID! + posts.type! + ".jpeg")
                imageRef.delete { error in
                    if let error = error {
                        print(error)
                    } else {// File deleted successfully
                            print("Image successfully deleted from Firebase")
                    }
                }
                self.currentPosts.removeLast()
                self.reversePosts.removeFirst()
                DispatchQueue.main.async(execute: {
                    self.tableView.reloadData()
                })
            }else{ print("valid") }
        }
    }
    
}
