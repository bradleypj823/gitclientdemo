//
//  NetworkController.swift
//  GithubClient
//
//  Created by Bradley Johnson on 1/19/15.
//  Copyright (c) 2015 BPJ. All rights reserved.
//


import UIKit


class NetworkController {
  
  //singleton
  class var sharedNetworkController : NetworkController {
    struct Static {
      static let instance : NetworkController = NetworkController()
    }
    return Static.instance
  }
  
  let clientSecret = "369dfda34211f6497b9f1d399b6aad977376350a"
  let clientID = "ee805a23323c6e26eecd"
  var urlSession : NSURLSession
  let accessTokenUserDefaultsKey = "accessToken"
  var accessToken : String?
  let imageQueue = NSOperationQueue()
  init() {
    let ephemeralConfig = NSURLSessionConfiguration.ephemeralSessionConfiguration()
    
    self.urlSession = NSURLSession(configuration: ephemeralConfig)
    if let accessToken = NSUserDefaults.standardUserDefaults().objectForKey(self.accessTokenUserDefaultsKey) as? String {
      self.accessToken = accessToken
    }
    
  }
  
  func requestAccessToken() {
    let url = "https://github.com/login/oauth/authorize?client_id=\(self.clientID)&scope=user,repo"
    
    UIApplication.sharedApplication().openURL(NSURL(string: url)!)
    
  }
  
  func handleCallbackURL(url : NSURL) {
    let code = url.query
    
  //This is one way you can pass back info in a POST, via passing items as parameters in the URL
    
//    let oauthURL = "https://github.com/login/oauth/access_token?\(code!)&client_id=\(self.clientID)&client_secret=\(self.clientSecret)"
//    let postRequest = NSMutableURLRequest(URL: NSURL(string: oauthURL)!)
//    postRequest.HTTPMethod = "POST"
    //postRequest.HTTPBody
    
    //THis is the 2nd way you can pass back info with a POST, and this is passing back info in the Body of the HTTP Request
    
    let bodyString = "\(code!)&client_id=\(self.clientID)&client_secret=\(self.clientSecret)"
    let bodyData = bodyString.dataUsingEncoding(NSASCIIStringEncoding, allowLossyConversion: true)
    let length = bodyData!.length
    let postRequest = NSMutableURLRequest(URL: NSURL(string: "https://github.com/login/oauth/access_token")!)
    postRequest.HTTPMethod = "POST"
    postRequest.setValue("\(length)", forHTTPHeaderField: "Content-Length")
    postRequest.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
    postRequest.HTTPBody = bodyData
    
    let dataTask = self.urlSession.dataTaskWithRequest(postRequest, completionHandler: { (data, response, error) -> Void in
      if error == nil {
        if let httpResponse = response as? NSHTTPURLResponse {
          switch httpResponse.statusCode {
          case 200...299:
            let tokenResponse = NSString(data: data, encoding: NSASCIIStringEncoding)
            println(tokenResponse)
            
            let accessTokenComponent = tokenResponse?.componentsSeparatedByString("&").first as String
            let accessToken = accessTokenComponent.componentsSeparatedByString("=").last
            println(accessToken!)
            
            NSUserDefaults.standardUserDefaults().setObject(accessToken!, forKey: self.accessTokenUserDefaultsKey)
            NSUserDefaults.standardUserDefaults().synchronize()
            
            
          default:
            println("default case")
          }
        }
      }
      
    })
    dataTask.resume()
    
  }
  
  func fetchRepositoriesForSearchTerm(searchTerm : String, callback : ([Repository]?, String) -> (Void)) {
    
    let url = NSURL(string: "https://api.github.com/search/repositories?q=\(searchTerm)")
    //Authorization: token OAUTH-TOKEN

    let request = NSMutableURLRequest(URL: url!)
    request.setValue("token \(self.accessToken!)", forHTTPHeaderField: "Authorization")
    
    //let url = NSURL(string: "http://127.0.0.1:3000")
    
    let dataTask = self.urlSession.dataTaskWithRequest(request, completionHandler: { (data, response, error) -> Void in
      if error == nil {
        if let httpResponse = response as? NSHTTPURLResponse {
          switch httpResponse.statusCode {
          case 200...299:
            println(httpResponse)
            let jsonDictionary = NSJSONSerialization.JSONObjectWithData(data, options: nil, error: nil) as [String : AnyObject]
            println(jsonDictionary)
          default:
            println("default")
          }
        }
      }
    })
    dataTask.resume()
  }
  
  func fetchUsersWithSearchTerm(searchTerm : String, completionHandler : (errorDescription : String?, results : [User]?) -> (Void)) {
    
    let url = NSURL(string: "https://api.github.com/search/users?q=\(searchTerm)")
    let dataTask = self.urlSession.dataTaskWithURL(url!, completionHandler: { (data, response, error) -> Void in
      if error != nil {
        println(error.localizedDescription)
        completionHandler(errorDescription: "Something went wrong, please try again", results: nil)
      } else {
        let httpResponse = response as NSHTTPURLResponse
        switch httpResponse.statusCode {
        case 200:
          println(httpResponse)
          var jsonError : NSError?
          var rawJSON = NSJSONSerialization.JSONObjectWithData(data, options: NSJSONReadingOptions.AllowFragments, error: &jsonError) as NSDictionary
          if error != nil {
            completionHandler(errorDescription: "Something went wrong, please try again", results: nil)
          } else {
            var users = User.parseJSONIntoUsers(rawJSON)
            NSOperationQueue.mainQueue().addOperationWithBlock({ () -> Void in
              completionHandler(errorDescription: nil, results: users)
            })
          }
        default:
          println(httpResponse.statusCode)
          println(httpResponse)
        }
      }
    })
    dataTask.resume()
  }
  
  func fetchAvatarImageWithURLString(urlString: String, completionHandler : (userImage : UIImage) -> (Void)) {
    
    let url = NSURL(string: urlString)
    
    self.imageQueue.addOperationWithBlock { () -> Void in
      let imageData = NSData(contentsOfURL: url!)
      let image = UIImage(data: imageData!)
      completionHandler(userImage: image!)
    }
  }
}