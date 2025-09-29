//
//  MQTTManager.swift
//  Promptly
//
//  Created by Sasha Bagrov on 28/09/2025.
//

import Foundation
import MQTTNIO
import Combine

class MQTTManager: ObservableObject {
    private var client: MQTTClient?
    
    @Published var isConnected = false
    @Published var receivedMessages: [String: String] = [:]
    
    private var messageHandlers: [String: (String) -> Void] = [:]
    private var cancellables = Set<AnyCancellable>()
    
    func connect(to host: String, port: Int = 1883) {
        client = MQTTClient(
            configuration: .init(
                target: .host(host, port: port),
                protocolVersion: .version3_1_1
            ),
            eventLoopGroupProvider: .createNew
        )
        
        setupEventHandlers()
        client?.connect()
    }
    
    private func setupEventHandlers() {
        client?.connectPublisher.sink { [weak self] response in
            DispatchQueue.main.async {
                self?.isConnected = true
            }
        }.store(in: &cancellables)
        
        client?.disconnectPublisher.sink { [weak self] reason in
            DispatchQueue.main.async {
                self?.isConnected = false
            }
        }.store(in: &cancellables)
        
        client?.messagePublisher.sink { [weak self] message in
            let messageString = message.payload.string ?? ""
            
            DispatchQueue.main.async {
                self?.receivedMessages[message.topic] = messageString
                
                if let handler = self?.messageHandlers[message.topic] {
                    handler(messageString)
                }
            }
        }.store(in: &cancellables)
    }
    
    func disconnect() {
        client?.disconnect()
    }
    
    func sendData(to topic: String, message: String) {
        client?.publish(message, to: topic, qos: .atLeastOnce)
    }
    
    func subscribe(to topic: String, onMessage: @escaping (String) -> Void) {
        messageHandlers[topic] = onMessage
        client?.subscribe(to: topic)
    }
    
    func unsubscribe(from topic: String) {
        messageHandlers.removeValue(forKey: topic)
        client?.unsubscribe(from: topic)
    }
    
    func subscribeToShowChanges(onChange: @escaping (String, String) -> Void) {
        let showsPattern = "shows/+"
        
        client?.messagePublisher
            .filter { $0.topic.hasPrefix("shows/") }
            .sink { message in
                let topic = message.topic
                let messageString = message.payload.string ?? ""
                
                if let showId = topic.split(separator: "/").last.map(String.init) {
                    DispatchQueue.main.async {
                        onChange(showId, messageString)
                    }
                }
            }
            .store(in: &cancellables)
        
        client?.subscribe(to: showsPattern)
    }
}
