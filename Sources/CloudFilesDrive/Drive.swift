import UIKit
import CloudFiles
import GoogleSignIn
import GoogleAPIClientForREST_Drive

public struct Drive {
  typealias SignInCompletion = (Result<Void, Swift.Error>) -> Void
  typealias DownloadCompletion = (Result<Data?, Swift.Error>) -> Void
  typealias AuthorizeCompletion = (Result<Void, Swift.Error>) -> Void
  typealias FetchCompletion = (Result<Fetch.Metadata?, Swift.Error>) -> Void
  typealias UploadCompletion = (Result<Upload.Metadata, Swift.Error>) -> Void

  public enum DriveError: Swift.Error {
    case unknown
    case missingScopes
    case fetch(Error)
    case signIn(Error)
    case upload(Error)
    case download(Error)
    case authorize(Error)
  }

  static var service = GTLRDriveService()

  var _unlink: () -> Void
  var _isLinked: () -> Bool
  var _fetch: (String, @escaping FetchCompletion) -> Void
  var _download: (String, @escaping DownloadCompletion) -> Void
  var _upload: (String, Data, @escaping UploadCompletion) -> Void
  var _authorize: (UIViewController, @escaping AuthorizeCompletion) -> Void
  var _signIn: (String, String, UIViewController, @escaping SignInCompletion) -> Void

  func unlink() {
    _unlink()
  }

  func isLinked() -> Bool {
    _isLinked()
  }

  func download(
    fileId: String,
    completion: @escaping DownloadCompletion
  ) {
    _download(fileId, completion)
  }

  func upload(
    fileName: String,
    input: Data,
    completion: @escaping UploadCompletion
  ) {
    _upload(fileName, input, completion)
  }

  func fetch(
    fileName: String,
    completion: @escaping FetchCompletion
  ) {
    _fetch(fileName, completion)
  }

  func authorize(
    controller: UIViewController,
    completion: @escaping AuthorizeCompletion
  ) {
    _authorize(controller, completion)
  }

  func signIn(
    apiKey: String,
    clientId: String,
    controller: UIViewController,
    completion: @escaping SignInCompletion
  ) {
    _signIn(apiKey, clientId, controller, completion)
  }
}

extension Drive {
  public static let unimplemented: Drive = .init(
    _unlink: { fatalError() },
    _isLinked: { fatalError() },
    _fetch: { _,_ in fatalError() },
    _download: { _,_ in fatalError() },
    _upload: { _,_,_ in fatalError() },
    _authorize: { _,_ in fatalError() },
    _signIn: { _,_,_,_ in fatalError() }
  )

  public static let live = Drive(
    _unlink: {
      GIDSignIn.sharedInstance.signOut()
    },
    _isLinked: {
      guard let currentUser = GIDSignIn.sharedInstance.currentUser,
            let grantedScopes = currentUser.grantedScopes,
            grantedScopes.contains(kGTLRAuthScopeDriveFile),
            grantedScopes.contains(kGTLRAuthScopeDriveAppdata) else { return false }
      return true
    },
    _fetch: { fileName, completion in
      let query = GTLRDriveQuery_FilesList.query()
      query.q = "name = '\(fileName)'"
      query.spaces = "appDataFolder"
      query.fields = "files(id, size, modifiedTime)"
      service.executeQuery(query) { _, result, error in
        if let error {
          if (error as NSError).domain == kGTLRErrorObjectDomain, (error as NSError).code == 404 {
            completion(.success(nil))
            return
          }
          completion(.failure(DriveError.fetch(error)))
          return
        }
        guard let metadata = (result as? GTLRDrive_FileList)?.files?.first,
              let date = metadata.modifiedTime?.date,
              let size = metadata.size?.floatValue,
              let id = metadata.identifier else {
          completion(.failure(DriveError.unknown))
          return
        }
        completion(.success(.init(
          id: id,
          size: size,
          lastModified: date
        )))
      }
    },
    _download: { fileId, completion in
      let query = GTLRDriveQuery_FilesGet.query(withFileId: fileId)
      service.executeQuery(query) { _, result, error in
        if let error {
          completion(.failure(DriveError.download(error)))
          return
        }
        guard let data = (result as? GTLRDataObject)?.data else {
          completion(.failure(DriveError.unknown))
          return
        }
        completion(.success(data))
      }
    },
    _upload: { fileName, data, completion in
      let file = GTLRDrive_File(json: [
        "name":"\(fileName)",
        "parents": ["appDataFolder"],
        "mimeType": "application/octet-stream"
      ])
      let params = GTLRUploadParameters(data: data, mimeType: "application/octet-stream")
      let query = GTLRDriveQuery_FilesCreate.query(withObject: file, uploadParameters: params)
      query.fields = "size, modifiedTime"
      service.executeQuery(query) { _, result, error in
        if let error {
          completion(.failure(DriveError.upload(error)))
          return
        }
        guard let file = result as? GTLRDrive_File,
              let size = file.size?.floatValue,
              let date = file.modifiedTime?.date else {
          completion(.failure(DriveError.unknown))
          return
        }
        completion(.success(.init(
          size: size,
          lastModified: date
        )))
      }
    },
    _authorize: { controller, completion in
      guard let user = GIDSignIn.sharedInstance.currentUser,
            let scopes = user.grantedScopes else {
        completion(.failure(DriveError.missingScopes))
        return
      }
      service.authorizer = user.authentication.fetcherAuthorizer()
      if !scopes.contains(kGTLRAuthScopeDriveFile) ||
          !scopes.contains(kGTLRAuthScopeDriveAppdata) {
        GIDSignIn.sharedInstance.addScopes([
          kGTLRAuthScopeDriveAppdata,
          kGTLRAuthScopeDriveFile,
        ], presenting: controller) { user, error in
          if let error {
            completion(.failure(DriveError.authorize(error)))
            return
          }
          completion(.success(()))
        }
      } else {
        completion(.success(()))
      }
    },
    _signIn: { apiKey, clientId, controller, completion in
      service.apiKey = apiKey
      GIDSignIn.sharedInstance.signIn(
        with: .init(clientID: clientId),
        presenting: controller) { user, error in
          if let error {
            completion(.failure(DriveError.signIn(error)))
            return
          }
          guard user != nil else {
            completion(.failure(DriveError.unknown))
            return
          }
          completion(.success(()))
        }
    }
  )
}

extension CloudFilesManager {
  public static func drive(
    apiKey: String,
    clientId: String,
    fileName: String
  ) -> CloudFilesManager {
    CloudFilesManager(
      link: .drive(
        apiKey: apiKey,
        clientId: clientId
      ),
      fetch: .drive(fileName: fileName),
      upload: .drive(fileName: fileName),
      unlink: .drive(),
      download: .drive(fileName: fileName),
      isLinked: .drive()
    )
  }
}