/// Copyright (c) 2020 Razeware LLC
/// 
/// Permission is hereby granted, free of charge, to any person obtaining a copy
/// of this software and associated documentation files (the "Software"), to deal
/// in the Software without restriction, including without limitation the rights
/// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
/// copies of the Software, and to permit persons to whom the Software is
/// furnished to do so, subject to the following conditions:
/// 
/// The above copyright notice and this permission notice shall be included in
/// all copies or substantial portions of the Software.
/// 
/// Notwithstanding the foregoing, you may not use, copy, modify, merge, publish,
/// distribute, sublicense, create a derivative work, and/or sell copies of the
/// Software in any work that is designed, intended, or marketed for pedagogical or
/// instructional purposes related to programming, coding, application development,
/// or information technology.  Permission for such use, copying, modification,
/// merger, publication, distribution, sublicensing, creation of derivative works,
/// or sale is expressly withheld.
/// 
/// This project and source code may use libraries or frameworks that are
/// released under various Open-Source licenses. Use of those libraries and
/// frameworks are governed by their own individual licenses.
///
/// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
/// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
/// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
/// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
/// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
/// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
/// THE SOFTWARE.

import UIKit
import Photos
import RxSwift

class PhotosViewController: UICollectionViewController {

  // MARK: public properties

  // MARK: private properties
  private lazy var photos = PhotosViewController.loadPhotos()
  private lazy var imageManager = PHCachingImageManager()

  private lazy var thumbnailSize: CGSize = {
    let cellSize = (self.collectionViewLayout as! UICollectionViewFlowLayout).itemSize
    return CGSize(width: cellSize.width * UIScreen.main.scale,
                  height: cellSize.height * UIScreen.main.scale)
  }()

  static func loadPhotos() -> PHFetchResult<PHAsset> {
    let allPhotosOptions = PHFetchOptions()
    allPhotosOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]
    return PHAsset.fetchAssets(with: allPhotosOptions)
  }
  
  // Должен быть приватным, тк добавить новое событие onNext можно только на этом экране
  private let selectedPhotosSubject = PublishSubject<UIImage>()
  // Публичный геттер для подписки на него всем заинтересованным
  var selectedPhotos: Observable<UIImage> {
    return selectedPhotosSubject.asObservable()
  }
  private let bag = DisposeBag()

  // MARK: View Controller
  override func viewDidLoad() {
    super.viewDidLoad()
    
    let authorized = PHPhotoLibrary.authorized.share()
    authorized
    // все false откидываются
      .skipWhile { $0 == false }
    // берем только один элемент
      .take(1)
      .subscribe { [weak self] _ in
        self?.photos = PhotosViewController.loadPhotos()
        DispatchQueue.main.async {
          self?.collectionView.reloadData()
        }
      }
      .disposed(by: bag)
    /*
    authorized
      .skip(1)
      .takeLast(1)
      .filter { $0 == false }
      .subscribe { [weak self] _ in
        // Не понял как это работает
        guard let errorMessage = self?.errorMessage else {
          return
        }
        DispatchQueue.main.async(execute: errorMessage)
      }
      .disposed(by: bag)
     */
  }

  override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)
    // Тк используется корзина для подписки на главном контроллере, который никогда не будет уничтожен, то и подписка будет жить вечно.
    // Чтобы избежать этого нужно передать onCompleted в subject.
    // Тк он Publish, то после этого он будет уничтожен.
    selectedPhotosSubject.onCompleted()

  }
  
  // MARK: - Private Methods
  
  private func errorMessage() {
    alert(title: "No Access To Camera Roll!",
          text: "You can grant access to Combinestagram from the Settings App")
    // У Completable нет доступа к .take()
    .asObservable()
    // Теперь алерт висит 5 сек и после этого завершается Completed
    .take(.seconds(5), scheduler: MainScheduler.instance)
    .subscribe { [weak self] in
      self?.dismiss(animated: true)
      _ = self?.navigationController?.popViewController(animated: true)
    }
    .disposed(by: bag)

  }

  // MARK: UICollectionView

  override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
    return photos.count
  }

  override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {

    let asset = photos.object(at: indexPath.item)
    let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "Cell", for: indexPath) as! PhotoCell

    cell.representedAssetIdentifier = asset.localIdentifier
    imageManager.requestImage(for: asset, targetSize: thumbnailSize, contentMode: .aspectFill, options: nil, resultHandler: { image, _ in
      if cell.representedAssetIdentifier == asset.localIdentifier {
        cell.imageView.image = image
      }
    })

    return cell
  }

  override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
    let asset = photos.object(at: indexPath.item)

    if let cell = collectionView.cellForItem(at: indexPath) as? PhotoCell {
      cell.flash()
    }

    imageManager.requestImage(for: asset, targetSize: view.frame.size, contentMode: .aspectFill, options: nil, resultHandler: { [weak self] image, info in
      guard let image = image, let info = info else { return }
      // Тк возвращается сразу 2 картинки: предпросмотр и полный размер
      if let isThumbNail = info[PHImageResultIsDegradedKey as NSString] as? Bool,
         !isThumbNail {
        // Берем только полный размер
        self?.selectedPhotosSubject.onNext(image)
      }
    })
  }
}
