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
import RxSwift
import RxRelay

class MainViewController: UIViewController {
  
  @IBOutlet weak var imagePreview: UIImageView!
  @IBOutlet weak var buttonClear: UIButton!
  @IBOutlet weak var buttonSave: UIButton!
  @IBOutlet weak var itemAdd: UIBarButtonItem!
  
  private let bag = DisposeBag()
  private let images = BehaviorRelay<[UIImage]>(value: [])
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    // Подписка для обновления картинки
    images
      .subscribe { [weak imagePreview] photos in
        guard let imagePreview else { return }
        imagePreview.image = photos.collage(size: imagePreview.frame.size)
      }
      .disposed(by: bag)
    // Подписка для обновления остального UI
    images
      .subscribe { [weak self] photos in
        self?.updateUI(photos: photos)
      }
      .disposed(by: bag)
  }
  
  // MARK: - Internal
  
  func showMessage(_ title: String, description: String? = nil) {
    alert(title: title, text: description)
      .subscribe()
      .disposed(by: bag)
  }
  
  // MARK: - Private
  
  private func updateUI(photos: [UIImage]) {
    buttonSave.isEnabled = photos.count > 0 && photos.count % 2 == 0
    buttonClear.isEnabled = photos.count > 0
    itemAdd.isEnabled = photos.count < 6
    title = photos.count > 0 ? "\(photos.count) photos" : "Collage"
  }
  
  private func updateNavigationIcon() {
    let icon = imagePreview.image?
      .scaled(CGSize(width: 22, height: 22))
      .withRenderingMode(.alwaysOriginal)
    navigationItem.leftBarButtonItem = UIBarButtonItem(image: icon,
                                                       style: .done,
                                                       target: nil,
                                                       action: nil)
  }
  
  // MARK: - Actions
  
  @IBAction func actionClear() {
    // новое событие onNext очищает массив
    images.accept([])
  }
  
  @IBAction func actionSave() {
    guard let image = imagePreview.image else { return }
    PhotoWriter.save(image)
      .asSingle()
      .subscribe(
        onSuccess: { [weak self] id in
          self?.showMessage("Saved with id: \(id)")
          self?.actionClear()
        },
        onError: { [weak self] error in
          self?.showMessage("Error", description: "\(error.localizedDescription)")
        }
      )
      .disposed(by: bag)
    
  }
  
  @IBAction func actionAdd() {
    let controller = storyboard?.instantiateViewController(withIdentifier: "PhotosViewController") as! PhotosViewController
    navigationController?.pushViewController(controller, animated: true)
    // .share создает подписку только для первого .subscribe
    // для всех следующих эта подписка является той же самой
    // подписываясь на нее есть гарантия получения одинаковых данных
    let newPhotos = controller.selectedPhotos.share()
    newPhotos
      .subscribe(
        onNext: { [weak self] image in
        guard let self else { return }
        let newImages = self.images.value + [image]
        // после этого все подписчики получат уведомление
        images.accept(newImages)
      },
        onDisposed: {
        print("Completed photo selection")
      })
      .disposed(by: bag)
    newPhotos
      .ignoreElements()
      .subscribe {
        self.updateNavigationIcon()
      }
      .disposed(by: bag)
  }
  
}
