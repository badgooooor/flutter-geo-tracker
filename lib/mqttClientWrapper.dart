import 'dart:convert';

import 'package:geo_tracking/constants.dart' as Constants;
import 'package:mqtt_client/mqtt_client.dart';
import 'models.dart';

class Payload {
  int id;
  double lat;
  double long;

  Payload(this.id, this.lat, this.long);

  Map toJson() => {'Id': id, 'Lat': lat, 'Long': long};
}

class MQTTClientWrapper {
  MqttClient client;

  MqttCurrentConnectionState connectionState = MqttCurrentConnectionState.IDLE;
  MqttSubscriptionState subscriptionState = MqttSubscriptionState.IDLE;

  void prepareMqttClient() async {
    _setupMqttClient();
    await _connectClient();
    _subscribeToTopic(Constants.topicName);
  }

  // Currently publish sample payload.
  void publishLocation(double latitude, double longitude) {
    Payload sample = Payload(1102501543184, latitude, longitude);
    String locationJson = jsonEncode(sample);
    _publishMessage(locationJson);
  }

  Future<void> _connectClient() async {
    try {
      print('MQTTClientWrapper:: Client connecting....');
      connectionState = MqttCurrentConnectionState.CONNECTING;
      await client.connect(Constants.username, Constants.password);
    } on Exception catch (e) {
      print('MQTTClientWrapper:: Client exception - $e');
      connectionState = MqttCurrentConnectionState.ERROR_WHEN_CONNECTING;
      client.disconnect();
    }

    if (client.connectionStatus.state == MqttConnectionState.connected) {
      connectionState = MqttCurrentConnectionState.CONNECTED;
      print('MQTTClientWrapper:: Client connected');
    } else {
      print(
          'MQTTClientWrapper::ERROR Client connection failed - disconnecting, status is ${client.connectionStatus}');
      connectionState = MqttCurrentConnectionState.ERROR_WHEN_CONNECTING;
      client.disconnect();
    }
  }

  void _setupMqttClient() {
    client = MqttClient.withPort(Constants.serverUri, '#', Constants.port);

    client.logging(on: false);
    client.keepAlivePeriod = 20;
    client.onDisconnected = _onDisconnected;
    client.onConnected = _onConnected;
    client.onSubscribed = _onSubscribed;
  }

  void _subscribeToTopic(String topicName) {
    print('MQTTClientWrapper::Subscribing to the $topicName topic');
    client.subscribe(topicName, MqttQos.atMostOnce);

    client.updates.listen((List<MqttReceivedMessage<MqttMessage>> c) {
      final MqttPublishMessage recMess = c[0].payload;
      final String newLocationJson =
          MqttPublishPayload.bytesToStringAsString(recMess.payload.message);

      print("MQTTClientWrapper::GOT A NEW MESSAGE $newLocationJson");
    });
  }

  void _publishMessage(String message) {
    final MqttClientPayloadBuilder builder = MqttClientPayloadBuilder();
    builder.addString(message);

    print(
        'MQTTClientWrapper::Publishing message $message to topic ${Constants.topicName}');
    client.publishMessage(
        Constants.topicName, MqttQos.exactlyOnce, builder.payload);
  }

  void _onSubscribed(String topic) {
    print('MQTTClientWrapper::Subscription confirmed for topic $topic');
    subscriptionState = MqttSubscriptionState.SUBSCRIBED;
  }

  void _onDisconnected() {
    print(
        'MQTTClientWrapper::OnDisconnected client callback - Client disconnection');
    if (client.connectionStatus.returnCode == MqttConnectReturnCode.solicited) {
      print(
          'MQTTClientWrapper::OnDisconnected callback is solicited, this is correct');
    }
    connectionState = MqttCurrentConnectionState.DISCONNECTED;
  }

  void _onConnected() {
    connectionState = MqttCurrentConnectionState.CONNECTED;
    print(
        'MQTTClientWrapper::OnConnected client callback - Client connection was sucessful');
    // onConnectedCallback();
  }
}
