// call_service.dart
import 'dart:async';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'websocket_service.dart';

enum CallState { idle, calling, ringing, connected, ended, error }

class CallService {
  static CallService? _instance;
  static CallService get instance => _instance ??= CallService._();

  CallService._();

  // État de l'appel
  CallState _callState = CallState.idle;
  CallState get callState => _callState;

  // WebRTC
  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  RTCVideoRenderer? _remoteRenderer;

  // Timer et durée d'appel - CORRECTION ICI
  Timer? _durationTimer; // Renommé de _callTimer
  Duration _callDuration = Duration.zero; // Changé de int à Duration
  final _callDurationController = StreamController<Duration>.broadcast();

  // États audio
  bool _isAudioMuted = false;
  bool _isSpeakerOn = false;
  bool get isAudioMuted => _isAudioMuted;
  bool get isSpeakerOn => _isSpeakerOn;

  // Etat vidéo
  bool _isVideoEnabled = false;
  bool get isVideoEnabled => _isVideoEnabled;

  // Informations d'appel
  String? _callerUid;
  String? _targetUid;
  String? get callerUid => _callerUid;
  String? get targetUid => _targetUid;

  // Stream controllers pour les événements
  final StreamController<CallState> _stateController =
      StreamController<CallState>.broadcast();
  final StreamController<String> _messageController =
      StreamController<String>.broadcast();
  final StreamController<MediaStream?> _remoteStreamController =
      StreamController<MediaStream?>.broadcast();

  // GETTERS POUR LES STREAMS
  Stream<Duration> get callDurationStream => _callDurationController.stream;
  Stream<CallState> get stateStream => _stateController.stream;
  Stream<String> get messageStream => _messageController.stream;
  Stream<MediaStream?> get remoteStreamStream => _remoteStreamController.stream;

  // GETTER POUR LA DURÉE ACTUELLE
  Duration get callDuration => _callDuration;

  // Configuration WebRTC
  final Map<String, dynamic> _rtcConfig = {
    'iceServers': [
      {'urls': 'stun:stun.l.google.com:19302'},
      {'urls': 'stun:stun1.l.google.com:19302'},
      {'urls': 'stun:stun2.l.google.com:19302'},
    ],
    'sdpSemantics': 'unified-plan',
  };

  final Map<String, dynamic> _mediaConstraints = {
    'audio': {
      'echoCancellation': true,
      'noiseSuppression': true,
      'autoGainControl': true,
    },
    'video': false,
  };

  final Map<String, dynamic> _videoConstraints = {
    'facingMode': 'user',
    'width': {'min': 640, 'ideal': 1280, 'max': 1920},
    'height': {'min': 480, 'ideal': 720, 'max': 1080},
    'frameRate': {'min': 15, 'ideal': 30, 'max': 60},
  };

  Future<void> initialize() async {
    _remoteRenderer = RTCVideoRenderer();
    await _remoteRenderer!.initialize();
  }

  Future<void> startCall(String targetUid) async {
    if (_callState != CallState.idle) return;

    _targetUid = targetUid;
    _setState(CallState.calling);

    try {
      await _createPeerConnection();
      final offer = await _peerConnection!.createOffer();
      await _peerConnection!.setLocalDescription(offer);

      WebSocketService.instance.sendMessage({
        'type': 'offer',
        'sdp': offer.sdp,
        'from': WebSocketService.instance.myUid,
        'to': targetUid,
      });
    } catch (e) {
      print('Erreur démarrage appel: $e');
      _setState(CallState.error);
    }
  }

  Future<void> handleOffer(String sdp, String fromUid) async {
    if (_callState != CallState.idle) {
      WebSocketService.instance.sendMessage({
        'type': 'reject',
        'from': WebSocketService.instance.myUid,
        'to': fromUid,
      });
      return;
    }

    _callerUid = fromUid;
    _setState(CallState.ringing);
  }

  Future<void> acceptCall(String sdp, String fromUid) async {
    try {
      await _createPeerConnection();
      await _peerConnection!.setRemoteDescription(
        RTCSessionDescription(sdp, 'offer'),
      );

      final answer = await _peerConnection!.createAnswer();
      await _peerConnection!.setLocalDescription(answer);

      WebSocketService.instance.sendMessage({
        'type': 'answer',
        'sdp': answer.sdp,
        'to': fromUid,
      });
    } catch (e) {
      print('Erreur acceptation appel: $e');
      _setState(CallState.error);
    }
  }

  Future<void> rejectCall(String fromUid) async {
    WebSocketService.instance.sendMessage({
      'type': 'reject',
      'from': WebSocketService.instance.myUid,
      'to': fromUid,
    });
    _setState(CallState.idle);
  }

  Future<void> handleAnswer(String sdp) async {
    try {
      await _peerConnection!.setRemoteDescription(
        RTCSessionDescription(sdp, 'answer'),
      );
    } catch (e) {
      print('Erreur traitement réponse: $e');
      _setState(CallState.error);
    }
  }

  Future<void> handleCandidate(dynamic candidateMap) async {
    try {
      final candidate = RTCIceCandidate(
        candidateMap['candidate'],
        candidateMap['sdpMid'],
        candidateMap['sdpMLineIndex'],
      );
      await _peerConnection?.addCandidate(candidate);
    } catch (e) {
      print('Erreur ajout candidat: $e');
    }
  }

  void handleCallRejected() {
    _setState(CallState.ended);
    _showMessage('Appel refusé');
  }

  void handleCallEnded() {
    _setState(CallState.ended);
    _showMessage('Appel terminé');
  }

  void hangUp() {
    WebSocketService.instance.sendMessage({
      'type': 'hangup',
      'from': WebSocketService.instance.myUid,
      'to': _targetUid ?? _callerUid,
    });
    _setState(CallState.ended);
  }

  Future<void> _createPeerConnection() async {
    try {
      _peerConnection = await createPeerConnection(_rtcConfig);

      _localStream = await navigator.mediaDevices.getUserMedia(
        _mediaConstraints,
      );
      _localStream!.getTracks().forEach((track) {
        _peerConnection!.addTrack(track, _localStream!);
      });

      _peerConnection!.onIceCandidate = (candidate) {
        if (candidate != null) {
          WebSocketService.instance.sendMessage({
            'type': 'candidate',
            'candidate': candidate.toMap(),
            'to': _targetUid ?? _callerUid,
          });
        }
      };

      _peerConnection!.onTrack = (event) {
        if (event.streams.isNotEmpty) {
          _remoteRenderer!.srcObject = event.streams[0];
          _remoteStreamController.add(event.streams[0]);
          _setState(CallState.connected);
          _startDurationTimer(); // CORRECTION ICI
        }
      };

      _peerConnection!.onConnectionState = (state) {
        print('État de connexion: $state');
        switch (state) {
          case RTCPeerConnectionState.RTCPeerConnectionStateConnected:
            _setState(CallState.connected);
            break;
          case RTCPeerConnectionState.RTCPeerConnectionStateDisconnected:
          case RTCPeerConnectionState.RTCPeerConnectionStateClosed:
          case RTCPeerConnectionState.RTCPeerConnectionStateFailed:
            handleCallEnded();
            break;
          default:
            break;
        }
      };

      _peerConnection!.onIceConnectionState = (state) {
        print('État ICE: $state');
        if (state == RTCIceConnectionState.RTCIceConnectionStateFailed) {
          _setState(CallState.error);
        }
      };
    } catch (e) {
      print('Erreur création peer connection: $e');
      _setState(CallState.error);
    }
  }

  void _setState(CallState newState) {
    if (_callState == newState) return;

    _callState = newState;
    _stateController.add(newState);

    if (newState == CallState.ended || newState == CallState.error) {
      _cleanupCall();
      // Retour à idle après 2 secondes
      Timer(const Duration(seconds: 2), () {
        _callState = CallState.idle;
        _stateController.add(CallState.idle);
      });
    }
  }

  void _cleanupCall() {
    _durationTimer?.cancel(); // CORRECTION ICI
    _durationTimer = null;
    _callDuration = Duration.zero; // CORRECTION ICI
    _peerConnection?.close();
    _peerConnection = null;
    _localStream?.dispose();
    _localStream = null;
    _remoteRenderer?.srcObject = null;
    _remoteStreamController.add(null);
    _callerUid = null;
    _targetUid = null;
    _isAudioMuted = false;
    _isSpeakerOn = false;
  }

  // MÉTHODE CORRIGÉE POUR LE TIMER
  void _startDurationTimer() {
    _durationTimer?.cancel(); // Annuler le timer précédent s'il existe
    _callDuration = Duration.zero; // Réinitialiser la durée
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _callDuration = Duration(seconds: _callDuration.inSeconds + 1);
      _callDurationController.add(
        _callDuration,
      ); // Envoyer la nouvelle durée au stream
    });
  }

  void _showMessage(String message) {
    _messageController.add(message);
  }

 void toggleMute() async {
    if (_localStream != null) {
      final audioTrack = _localStream!.getAudioTracks().first;

      if (_isAudioMuted) {
        // Réactiver avec de nouvelles contraintes
        await audioTrack.applyConstraints({
          'audio': {'echoCancellation': true, 'noiseSuppression': true},
        });
        _isAudioMuted = false;
      } else {
        _isAudioMuted = true;
        // Couper en appliquant des contraintes vides
        audioTrack.stop();
      }
    }
  }

  void toggleSpeaker() {
    _isSpeakerOn = !_isSpeakerOn;
    Helper.setSpeakerphoneOn(_isSpeakerOn);
  }

  void toggleVideo() {
    _isVideoEnabled = !_isVideoEnabled;
    if (_localStream != null) {
      final videoTrack = _localStream!.getVideoTracks().first;
      videoTrack.enabled = _isVideoEnabled;
    } else if (_isVideoEnabled) {
      // Si on active la vidéo, on doit demander l'accès à la caméra
      _videoConstraints['video'] = true;
      navigator.mediaDevices.getUserMedia(_videoConstraints).then((stream) {
        _localStream = stream;
        _peerConnection?.addTrack(
          _localStream!.getVideoTracks().first,
          _localStream!,
        );
      });
    }
  }

  // MÉTHODE CORRIGÉE POUR LE FORMATAGE
  String formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));

    if (duration.inHours > 0) {
      return "${twoDigits(duration.inHours)}:$twoDigitMinutes:$twoDigitSeconds";
    } else {
      return "$twoDigitMinutes:$twoDigitSeconds";
    }
  }

  void dispose() {
    _cleanupCall();
    _remoteRenderer?.dispose();
    _stateController.close();
    _messageController.close();
    _remoteStreamController.close();
    _callDurationController.close(); // AJOUT ICI
  }
}
