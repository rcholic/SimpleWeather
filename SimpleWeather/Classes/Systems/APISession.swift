//
//  ForecastNetworking.swift
//  SimpleWeather
//
//  Created by Ryan Nystrom on 11/17/16.
//  Copyright © 2016 Ryan Nystrom. All rights reserved.
//

import Foundation

class APISession {

    let session: URLSession
    let key: String
    let limiter: RateLimiter

    init(key: String, limiter: RateLimiter, session: URLSession = URLSession.shared) {
        self.key = key
        self.limiter = limiter
        self.session = session
    }

    // MARK: Public API

    public func getForecast(lat: Double, lon: Double, completion: @escaping ([String: Any]?, Error?) -> Void) {
        guard let url = forecastURL(lat: lat, lon: lon) else { return }

        if limiter.attempt() {
            let task = session.dataTask(with: url, completionHandler: { (data: Data?, response: URLResponse?, error: Error?) in
                if let data = data,
                let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                    self.saveCachedResponse(url: url, data: data)
                    completion(json, nil)
                } else {
                    completion(nil, error)
                }
            })
            task.resume()
        } else {
            if let json = fetchCachedResponse(url: url) {
                completion(json, nil)
            } else {
                completion(nil, nil)
            }
        }
    }

    // MARK: Private API

    private var base: String {
        return "http://api.wunderground.com/api/\(key)/"
    }

    private func base(functions: [String], query: String) -> String {
        return base + functions.joined(separator: "/") + "/q/" + query + ".json"
    }

    private func forecastURL(lat: Double, lon: Double) -> URL? {
        let latlon = String(format: "%.2f,%.2f", lat, lon)
        let functions = ["forecast", "geolookup", "conditions", "forecast10day", "alerts", "hourly"]
        return URL(string: base(functions: functions, query: latlon))
    }

    private func cacheURL(url: URL) -> URL? {
        let diskKey = url.diskCacheKey
        if let cachePath = NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true).first {
            return URL(fileURLWithPath: cachePath).appendingPathComponent(diskKey)
        } else {
            return nil
        }
    }

    private func fetchCachedResponse(url: URL) -> [String: Any]? {
        if let fileURL = cacheURL(url: url),
            let data = try? Data(contentsOf: fileURL),
            let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
            return json
        } else {
            return nil
        }
    }

    private func saveCachedResponse(url: URL, data: Data) {
        if let fileURL = cacheURL(url: url) {
            do {
                try data.write(to: fileURL, options: [.atomic])
            } catch let err {
                print(err)
            }
        }
    }
    
}