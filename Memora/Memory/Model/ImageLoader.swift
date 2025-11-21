// ImageLoader.swift
// Combined, thread-safe image loader with local + remote loading and UIImageView helpers.
// Adds a small activity indicator on UIImageView while loading and fade-in animation.

import UIKit

final class ImageLoader {
    static let shared = ImageLoader()

    /// Shared cache keyed by string (either URL.absoluteString or local file path)
    let cache = NSCache<NSString, UIImage>()

    /// Active URLSession tasks for remote downloads
    private var tasks: [URL: URLSessionDataTask] = [:]

    /// Completion lists for in-flight remote downloads (to support multiple callers)
    private var completions: [URL: [(UIImage?) -> Void]] = [:]

    /// Serial queue to protect tasks/completions maps and to perform local file I/O bookkeeping
    private let syncQueue = DispatchQueue(label: "com.app.ImageLoader.sync")

    /// Background queue for disk reads
    private let ioQueue = DispatchQueue(label: "com.app.ImageLoader.io", qos: .userInitiated)

    private init() {}

    // MARK: - Remote loading

    /// Load image from remote URL. Calls completion on main queue.
    /// Dedupes concurrent requests for the same URL: multiple callers receive the same result.
    func load(from url: URL, completion: @escaping (UIImage?) -> Void) {
        let key = url.absoluteString as NSString

        // Quick cache check
        if let cached = cache.object(forKey: key) {
            DispatchQueue.main.async { completion(cached) }
            return
        }

        // Append to completion list if task already in-flight, otherwise create list & start task
        var shouldCreateTask = false
        syncQueue.sync {
            if var list = completions[url] {
                list.append(completion)
                completions[url] = list
            } else {
                completions[url] = [completion]
                shouldCreateTask = true
            }
        }
        if !shouldCreateTask {
            return
        }

        // Build request (reloadIgnoringLocalCacheData helps during dev)
        var req = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 30)
        req.setValue("image/*", forHTTPHeaderField: "Accept")

        let task = URLSession.shared.dataTask(with: req) { [weak self] data, _, _ in
            guard let self = self else { return }

            var image: UIImage? = nil
            if let d = data, let img = UIImage(data: d) {
                image = img
                self.cache.setObject(img, forKey: key)
            }

            // Capture & clear callbacks atomically
            var callbacks: [(UIImage?) -> Void] = []
            self.syncQueue.sync {
                callbacks = self.completions[url] ?? []
                self.completions[url] = nil
                self.tasks[url] = nil
            }

            DispatchQueue.main.async {
                for cb in callbacks {
                    cb(image)
                }
            }
        }

        syncQueue.sync {
            tasks[url] = task
        }
        task.resume()
    }

    /// Cancel an in-flight remote download and drop pending completions for that URL.
    func cancelLoad(for url: URL) {
        syncQueue.sync {
            if let task = tasks[url] {
                task.cancel()
                tasks[url] = nil
            }
            completions[url] = nil
        }
    }

    /// Alias convenience
    func cancel(url: URL) {
        cancelLoad(for: url)
    }

    // MARK: - Local loading

    /// Load image from a local file URL (documents directory or any file url). Caches result keyed by file path.
    func loadLocal(from fileURL: URL, completion: @escaping (UIImage?) -> Void) {
        let key = fileURL.path as NSString

        // If cached, return quickly
        if let cached = cache.object(forKey: key) {
            DispatchQueue.main.async { completion(cached) }
            return
        }

        // Read from disk on background queue
        ioQueue.async { [weak self] in
            guard let self = self else { return }
            let image = UIImage(contentsOfFile: fileURL.path)
            if let img = image {
                self.cache.setObject(img, forKey: key)
            }
            DispatchQueue.main.async {
                completion(image)
            }
        }
    }

    // MARK: - Convenience helpers

    /// Decide remote vs local based on the provided string.
    /// If string starts with http/https → remote.
    /// Otherwise treat as a MemoryStore attachment filename and load local.
    func loadImage(from pathOrUrlString: String, completion: @escaping (UIImage?) -> Void) {
        let trimmed = pathOrUrlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { completion(nil); return }

        if let url = URL(string: trimmed), url.scheme?.lowercased().hasPrefix("http") == true {
            load(from: url, completion: completion)
            return
        }

        // Treat as local attachment filename saved by MemoryStore
        let localURL = MemoryStore.shared.urlForAttachment(filename: trimmed)
        loadLocal(from: localURL, completion: completion)
    }
}

// MARK: - UIImageView extension (convenience + spinner + fade)

private var AssociatedURLKey: UInt8 = 0
private var AssociatedSpinnerKey: UInt8 = 0

extension UIImageView {
    /// Set image from a remote URL string or local filename string.
    /// Shows an activity indicator while loading and fades the image in when available.
    /// - parameter urlString: either "https://..." or an attachment filename saved in MemoryStore (e.g. "img_XXX.jpg")
    /// - parameter placeholder: optional placeholder shown until image loads
    func setImage(from urlString: String?, placeholder: UIImage? = nil) {
        // Run on main
        DispatchQueue.main.async {
            // If placeholder provided, show it now (alpha 1)
            if let ph = placeholder {
                self.image = ph
                self.alpha = 1.0
            }
        }

        // Cancel previous remote load if any
        if let previous = objc_getAssociatedObject(self, &AssociatedURLKey) as? String,
           let prevURL = URL(string: previous), prevURL.scheme?.lowercased().hasPrefix("http") == true
        {
            ImageLoader.shared.cancelLoad(for: prevURL)
        }

        // Remove any existing spinner
        removeSpinner()

        // Clear associated object then set new one if provided
        objc_setAssociatedObject(self, &AssociatedURLKey, nil, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)

        guard let s = urlString?.trimmingCharacters(in: .whitespacesAndNewlines), !s.isEmpty else {
            return
        }

        // Associate the string so we can ignore stale callbacks
        objc_setAssociatedObject(self, &AssociatedURLKey, s, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)

        // Show spinner (but only for remote loads or disk local loads that might take time)
        showSpinner()

        // Kick off load (ImageLoader decides remote vs local)
        ImageLoader.shared.loadImage(from: s) { [weak self] img in
            guard let self = self else { return }

            // Ensure the imageView still expects this load
            let current = objc_getAssociatedObject(self, &AssociatedURLKey) as? String
            guard current == s else {
                // stale - drop result and stop spinner
                self.removeSpinner()
                return
            }

            self.removeSpinner()

            // If image is nil, keep placeholder (already set) or set "photo" icon
            guard let image = img else {
                DispatchQueue.main.async {
                    if self.image == nil {
                        self.image = placeholder ?? UIImage(systemName: "photo")
                        self.alpha = 1.0
                    }
                }
                return
            }

            // Fade-in the loaded image
            DispatchQueue.main.async {
                self.alpha = 0.0
                self.image = image
                UIView.animate(withDuration: 0.28) {
                    self.alpha = 1.0
                }
            }
        }
    }

    /// Cancel an in-flight image load associated with this image view (if any)
    func cancelImageLoad() {
        guard let s = objc_getAssociatedObject(self, &AssociatedURLKey) as? String else { return }
        objc_setAssociatedObject(self, &AssociatedURLKey, nil, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)

        if let url = URL(string: s), url.scheme?.lowercased().hasPrefix("http") == true {
            ImageLoader.shared.cancelLoad(for: url)
        }
        removeSpinner()
    }

    // MARK: - Spinner helpers (internal)

    private func showSpinner() {
        DispatchQueue.main.async {
            // If spinner already present, don't add another
            if let _ = objc_getAssociatedObject(self, &AssociatedSpinnerKey) as? UIActivityIndicatorView {
                return
            }

            let spinner: UIActivityIndicatorView
            if #available(iOS 13.0, *) {
                spinner = UIActivityIndicatorView(style: .large)
            } else {
                spinner = UIActivityIndicatorView(style: .whiteLarge)
            }
            spinner.translatesAutoresizingMaskIntoConstraints = false
            spinner.hidesWhenStopped = true
            spinner.startAnimating()

            // slight dark blur background so spinner is visible on any image
            let bg = UIView()
            bg.translatesAutoresizingMaskIntoConstraints = false
            bg.backgroundColor = UIColor(white: 0, alpha: 0.18)
            bg.layer.cornerRadius = 8
            bg.clipsToBounds = true
            bg.alpha = 0.95

            // container view holds spinner and background
            let container = UIView()
            container.translatesAutoresizingMaskIntoConstraints = false
            container.isUserInteractionEnabled = false
            container.addSubview(bg)
            container.addSubview(spinner)

            self.addSubview(container)
            // bring to front
            self.bringSubviewToFront(container)

            // constraints
            NSLayoutConstraint.activate([
                container.centerXAnchor.constraint(equalTo: self.centerXAnchor),
                container.centerYAnchor.constraint(equalTo: self.centerYAnchor),
                bg.leadingAnchor.constraint(equalTo: container.leadingAnchor),
                bg.trailingAnchor.constraint(equalTo: container.trailingAnchor),
                bg.topAnchor.constraint(equalTo: container.topAnchor),
                bg.bottomAnchor.constraint(equalTo: container.bottomAnchor),
                spinner.centerXAnchor.constraint(equalTo: container.centerXAnchor),
                spinner.centerYAnchor.constraint(equalTo: container.centerYAnchor),
                // minimum container size
                container.widthAnchor.constraint(greaterThanOrEqualToConstant: 44),
                container.heightAnchor.constraint(greaterThanOrEqualToConstant: 44)
            ])

            objc_setAssociatedObject(self, &AssociatedSpinnerKey, container, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }

    private func removeSpinner() {
        DispatchQueue.main.async {
            if let container = objc_getAssociatedObject(self, &AssociatedSpinnerKey) as? UIView {
                container.removeFromSuperview()
                objc_setAssociatedObject(self, &AssociatedSpinnerKey, nil, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            }
        }
    }
}
