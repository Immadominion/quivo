import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config.dart';
import '../services/gateway_service.dart';
import 'models.dart';

/// Client-side lifecycle. Server phases are lobby/question/reveal/settling/complete;
/// idle/connecting/error are client-only.
enum GamePhase { idle, connecting, lobby, question, reveal, settling, complete, error }

GamePhase _phaseFromWire(String? s) {
  switch (s) {
    case 'lobby':
      return GamePhase.lobby;
    case 'question':
      return GamePhase.question;
    case 'reveal':
      return GamePhase.reveal;
    case 'settling':
      return GamePhase.settling;
    case 'complete':
      return GamePhase.complete;
    default:
      return GamePhase.lobby;
  }
}

@immutable
class GameState {
  const GameState({
    this.phase = GamePhase.idle,
    this.code,
    this.sessionId,
    this.link = LinkState.idle,
    this.players = const [],
    this.me,
    this.question,
    this.questionDeadline,
    this.myChoice,
    this.correctChoice,
    this.board = const [],
    this.settlement,
    this.chainReady = false,
    this.lastAnchorMs,
    this.reconnecting = false,
    this.error,
    this.demo = false,
  });

  final GamePhase phase;
  final String? code;
  final String? sessionId;
  final LinkState link;
  final List<PlayerLite> players;
  final MyStanding? me;
  final QuestionPublic? question;
  final DateTime? questionDeadline; // local clock, avoids server skew
  final int? myChoice;
  final int? correctChoice;
  final List<LeaderboardEntry> board;
  final Settlement? settlement;
  final bool chainReady;
  final int? lastAnchorMs;
  final bool reconnecting;
  final String? error;
  final bool demo;

  bool get answered => myChoice != null;
  int get playerCount => players.length;

  GameState copyWith({
    GamePhase? phase,
    String? code,
    String? sessionId,
    LinkState? link,
    List<PlayerLite>? players,
    MyStanding? me,
    QuestionPublic? question,
    DateTime? questionDeadline,
    Object? myChoice = _sentinel,
    Object? correctChoice = _sentinel,
    List<LeaderboardEntry>? board,
    Settlement? settlement,
    bool? chainReady,
    int? lastAnchorMs,
    bool? reconnecting,
    Object? error = _sentinel,
    bool? demo,
  }) {
    return GameState(
      phase: phase ?? this.phase,
      code: code ?? this.code,
      sessionId: sessionId ?? this.sessionId,
      link: link ?? this.link,
      players: players ?? this.players,
      me: me ?? this.me,
      question: question ?? this.question,
      questionDeadline: questionDeadline ?? this.questionDeadline,
      myChoice: myChoice == _sentinel ? this.myChoice : myChoice as int?,
      correctChoice: correctChoice == _sentinel ? this.correctChoice : correctChoice as int?,
      board: board ?? this.board,
      settlement: settlement ?? this.settlement,
      chainReady: chainReady ?? this.chainReady,
      lastAnchorMs: lastAnchorMs ?? this.lastAnchorMs,
      reconnecting: reconnecting ?? this.reconnecting,
      error: error == _sentinel ? this.error : error as String?,
      demo: demo ?? this.demo,
    );
  }

  static const _sentinel = Object();
}

class GameController extends Notifier<GameState> {
  GatewayService? _svc;
  StreamSubscription? _msgSub;
  StreamSubscription? _linkSub;
  String? _name;
  String? _wallet;
  int _retries = 0;
  Timer? _retryTimer;

  @override
  GameState build() {
    ref.onDispose(_teardown);
    return const GameState();
  }

  Future<void> join(String code, {required String name, required String wallet}) async {
    _teardown();
    _name = name;
    _wallet = wallet;
    _retries = 0;
    state = GameState(phase: GamePhase.connecting, code: code.trim(), link: LinkState.connecting);
    await _open();
  }

  Future<void> _open() async {
    final svc = GatewayService(kGateway);
    _svc = svc;
    _msgSub = svc.messages.listen(_onMessage);
    _linkSub = svc.link.listen(_onLink);
    await svc.connect();
    // Send join once the socket is open (connect() awaits ready).
    _sendJoin();
  }

  void _sendJoin() {
    final code = state.code;
    if (code == null) return;
    _svc?.send({'t': 'join', 'code': code, 'name': _name ?? 'player', 'wallet': _wallet});
  }

  void answer(int choice) {
    if (state.phase != GamePhase.question || state.answered) return;
    final q = state.question;
    if (q == null) return;
    _svc?.send({'t': 'answer', 'questionIndex': q.index, 'choice': choice});
    state = state.copyWith(myChoice: choice); // optimistic; server is source of truth on reveal
  }

  void leave() {
    _teardown();
    state = const GameState();
  }

  void _onLink(LinkState link) {
    if (link == LinkState.closed && _shouldReconnect) {
      _scheduleReconnect();
    }
    state = state.copyWith(link: link);
  }

  bool get _shouldReconnect =>
      _name != null &&
      state.phase != GamePhase.idle &&
      state.phase != GamePhase.complete &&
      state.phase != GamePhase.error;

  void _scheduleReconnect() {
    if (_retries >= 5) {
      state = state.copyWith(phase: GamePhase.error, error: 'Lost connection to the game.', reconnecting: false);
      return;
    }
    _retries++;
    state = state.copyWith(reconnecting: true);
    final backoff = Duration(milliseconds: 400 * _retries);
    _retryTimer?.cancel();
    _retryTimer = Timer(backoff, () async {
      _msgSub?.cancel();
      _linkSub?.cancel();
      _svc?.dispose();
      await _open();
    });
  }

  void _onMessage(Map<String, dynamic> m) {
    switch (m['t'] as String?) {
      case 'joined':
        _retries = 0;
        state = state.copyWith(sessionId: m['sessionId'] as String?, reconnecting: false);
        break;
      case 'state':
        _applyState(m);
        break;
      case 'question':
        final q = QuestionPublic.fromJson((m['question'] as Map).cast<String, dynamic>());
        state = state.copyWith(
          phase: GamePhase.question,
          question: q,
          questionDeadline: DateTime.now().add(Duration(milliseconds: q.durationMs)),
          myChoice: null,
          correctChoice: null,
        );
        break;
      case 'reveal':
        state = state.copyWith(
          phase: GamePhase.reveal,
          correctChoice: (m['correctChoice'] as num?)?.toInt(),
          board: _board(m['leaderboard']),
          me: _meFromBoard(m['leaderboard']),
        );
        break;
      case 'podium':
        state = state.copyWith(phase: GamePhase.settling, board: _board(m['leaderboard']), me: _meFromBoard(m['leaderboard']));
        break;
      case 'settled':
        state = state.copyWith(
          phase: GamePhase.complete,
          settlement: Settlement.fromJson((m['settlement'] as Map).cast<String, dynamic>()),
        );
        break;
      case 'anchored':
        state = state.copyWith(lastAnchorMs: (m['ms'] as num?)?.toInt());
        break;
      case 'chainReady':
        state = state.copyWith(chainReady: true);
        break;
      case 'error':
        final code = m['code'] as String?;
        // A failed settle still ends the game; only a failed join is fatal to the session.
        state = state.copyWith(
          phase: code == 'join_failed' ? GamePhase.error : state.phase,
          error: m['message'] as String? ?? 'Something went wrong.',
        );
        break;
      case 'left':
        if (_shouldReconnect) _scheduleReconnect();
        break;
    }
  }

  void _applyState(Map<String, dynamic> m) {
    final players = (m['players'] as List?)?.map((p) => PlayerLite.fromJson((p as Map).cast<String, dynamic>())).toList() ?? const <PlayerLite>[];
    final youRaw = m['you'];
    final me = youRaw is Map ? MyStanding.fromJson(youRaw.cast<String, dynamic>()) : state.me;
    // Phases cycle (question↔reveal each round), so state frames must NOT drive transitions - the
    // discrete events (question/reveal/podium/settled) do, and colyseus delivers them reliably.
    // A state frame only adopts the server phase on first sync (joining, possibly mid-game).
    final phase = state.phase == GamePhase.connecting ? _phaseFromWire(m['phase'] as String?) : state.phase;
    state = state.copyWith(phase: phase, players: players, me: me, reconnecting: false);
  }

  List<LeaderboardEntry> _board(dynamic raw) =>
      (raw as List?)?.map((e) => LeaderboardEntry.fromJson((e as Map).cast<String, dynamic>())).toList() ?? const [];

  MyStanding? _meFromBoard(dynamic raw) {
    final rows = _board(raw);
    for (final r in rows) {
      if (r.wallet == _wallet) return MyStanding(score: r.score, rank: r.rank);
    }
    return state.me;
  }

  void _teardown() {
    _retryTimer?.cancel();
    _msgSub?.cancel();
    _linkSub?.cancel();
    _svc?.dispose();
    _svc = null;
  }

  /// Debug-only: load a fabricated state (design QA / offline demo). No socket involved.
  void debugLoad(GameState s, {String? myWallet}) {
    _teardown();
    if (myWallet != null) _wallet = myWallet;
    state = s.copyWith(demo: true);
  }
}

final gameControllerProvider = NotifierProvider<GameController, GameState>(GameController.new);
