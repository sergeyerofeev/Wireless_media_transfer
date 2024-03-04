final configuration = <String, dynamic>{
  'iceServers': [
    {'urls': 'stun:stun.l.google.com:19302'},
  ],
  'sdpSemantics': 'unified-plan'
};

final peerConnectionConstraints = <String, dynamic>{
  'mandatory': {},
  'optional': [
    {'DtlsSrtpKeyAgreement': true},
  ],
};

final offerConstraints = <String, dynamic>{
  'mandatory': {
    'OfferToReceiveAudio': true,
    'OfferToReceiveVideo': true,
  },
  'optional': [],
};

final mediaConstraints = <String, dynamic>{
  'audio': true,
  'video': {
    'mandatory': {
      'minWidth': '1920',
      'minHeight': '1080',
      'minFrameRate': '30',
    },
    'facingMode': 'environment', // 'user'
    'optional': [],
  }
};
