using Toybox.Activity;
using Toybox.ActivityRecording;
using Toybox.Attention;
using Toybox.System;

module FiveByFiveState {
    const INIT = :INIT;
    const SELECT_WORKOUT = :SELECT_WORKOUT;
    const WORKOUT_PREVIEW = :WORKOUT_PREVIEW;
    const ASK_WARMUP = :ASK_WARMUP;
    const WARMUP = :WARMUP;
    const REST = :REST;
    const WORK = :WORK;
    const CHOICE = :CHOICE;
    const SETTINGS = :SETTINGS;
    const CLOCK = :CLOCK;
    const EXIT_PROMPT = :EXIT_PROMPT;
    const SKIPPED_PROMPT = :SKIPPED_PROMPT;
    const MAKEUP = :MAKEUP;
    const SUMMARY = :SUMMARY;
    const ACTIVITY_SAVE = :ACTIVITY_SAVE;
    const EXIT = :EXIT;
}

class FiveByFiveStateMachine {
    const WEIGHT_EDIT_STEP = 2.5;

    var _state;
    var _segmentStartMs;
    var _frozenElapsedMs;

    var _profile;
    var _workoutName;
    var _plan;

    var _exerciseIndex;
    var _setIndex;

    var _workoutCursor;
    var _warmupCursor;
    var _choiceCursor;
    var _settingsCursor;
    var _exitPromptCursor;
    var _skippedPromptCursor;

    var _weightEditOpen;
    var _weightEditValue;

    var _activitySession;
    var _sessionStarted;
    var _sessionStartMs;
    var _summaryElapsedMs;
    var _warmupStarted;

    var _exerciseEasyMap;

    var _stateBeforeSettings;
    var _stateBeforeClock;
    var _stateBeforeExitPrompt;

    var _skippedSegments;
    var _makeupIndex;
    var _previewScroll;

    function initialize() {
        _profile = FiveByFiveStorage.loadProfile();
        _plan = [];

        _exerciseIndex = 0;
        _setIndex = 0;

        _workoutCursor = 0;
        _warmupCursor = 0;
        _choiceCursor = 0;
        _settingsCursor = 0;
        _exitPromptCursor = 0;
        _skippedPromptCursor = 0;

        _weightEditOpen = false;
        _weightEditValue = 0.0;

        _activitySession = null;
        _sessionStarted = false;
        _sessionStartMs = null;
        _summaryElapsedMs = null;
        _warmupStarted = false;

        _exerciseEasyMap = {};

        _stateBeforeSettings = null;
        _stateBeforeClock = null;
        _stateBeforeExitPrompt = null;

        _skippedSegments = [];
        _makeupIndex = 0;
        _previewScroll = 0;

        _state = FiveByFiveState.INIT;
        _segmentStartMs = System.getTimer();
        _frozenElapsedMs = null;

        _resolveInitialState();
    }

    function _resolveInitialState() {
        var lastWorkout = _profile[:lastWorkout];
        if (lastWorkout == null) {
            _transitionTo(FiveByFiveState.SELECT_WORKOUT);
            return;
        }

        _workoutName = FiveByFiveWorkoutLogic.getOppositeWorkout(lastWorkout);
        _buildPlanForWorkout();
        _transitionTo(FiveByFiveState.WORKOUT_PREVIEW);
    }

    function _transitionTo(nextState) {
        _state = nextState;
        _segmentStartMs = System.getTimer();
        _frozenElapsedMs = null;
    }

    function _enterSegment(nextState) {
        _transitionTo(nextState);
        _notifySegmentStart();
    }

    function _freezeElapsed() {
        var elapsedMs = System.getTimer() - _segmentStartMs;
        if (elapsedMs < 0) {
            elapsedMs = 0;
        }
        _frozenElapsedMs = elapsedMs;
    }

    function _buildPlanForWorkout() {
        _plan = FiveByFiveWorkoutLogic.getWorkout(_workoutName);
        _exerciseIndex = 0;
        _setIndex = 0;
        _previewScroll = 0;
        _warmupStarted = false;

        _exerciseEasyMap = {};
        for (var i = 0; i < _plan.size(); i += 1) {
            var ex = _plan[i];
            _exerciseEasyMap[ex[:name]] = false;
        }
    }

    function shouldExit() {
        return _state == FiveByFiveState.EXIT;
    }

    function _currentExercise() {
        if ((_plan == null) || (_exerciseIndex >= _plan.size())) {
            return null;
        }
        return _plan[_exerciseIndex];
    }

    function _currentWeight() {
        var ex = _currentExercise();
        if (ex == null) {
            return 0.0;
        }

        var name = ex[:name];
        var weights = _profile[:weights];
        var value = weights[name];

        if (value == null) {
            return 0.0;
        }
        return value.toFloat();
    }

    function _setCurrentWeight(value) {
        var ex = _currentExercise();
        if (ex == null) {
            return;
        }

        if (value < 0.0) {
            value = 0.0;
        }

        var name = ex[:name];
        var weights = _profile[:weights];
        weights[name] = value;
    }

    function _recordLap() {
        if (_activitySession == null) {
            return;
        }

        try {
            _activitySession.addLap();
        } catch (ex) {
        }
    }

    function _startActivitySessionIfNeeded() {
        if (_activitySession != null) {
            return;
        }

        if (!(Toybox has :ActivityRecording)) {
            return;
        }

        try {
            _activitySession = ActivityRecording.createSession({
                :name => "FiveByFive",
                :sport => Activity.SPORT_TRAINING,
                :subSport => Activity.SUB_SPORT_STRENGTH_TRAINING
            });

            if (_activitySession != null) {
                _activitySession.start();
            }
        } catch (ex) {
            _activitySession = null;
        }
    }

    function _stopAndSaveActivity() {
        if (_activitySession == null) {
            _sessionStarted = false;
            return;
        }

        try {
            if (_activitySession.isRecording()) {
                _activitySession.stop();
            }
            _activitySession.save();
        } catch (ex) {
        }

        _activitySession = null;
        _sessionStarted = false;
    }

    function _stopAndDiscardActivity() {
        if (_activitySession == null) {
            _sessionStarted = false;
            return;
        }

        try {
            if ((_activitySession has :discard)) {
                _activitySession.discard();
            } else {
                if (_activitySession.isRecording()) {
                    _activitySession.stop();
                }
            }
        } catch (ex) {
        }

        _activitySession = null;
        _sessionStarted = false;
    }

    function _applyProgressionToNextSession() {
        var weights = _profile[:weights];

        for (var i = 0; i < _plan.size(); i += 1) {
            var ex = _plan[i];
            var exerciseName = ex[:name];
            if (_exerciseEasyMap[exerciseName]) {
                var currentWeight = weights[exerciseName].toFloat();
                weights[exerciseName] = currentWeight + ex[:increment].toFloat();
            }
        }
    }

    function _saveCompletedSession() {
        _applyProgressionToNextSession();
        _profile[:lastWorkout] = _workoutName;
        FiveByFiveStorage.saveProfile(_profile);
        _stopAndSaveActivity();
    }

    function _saveSessionWithoutProgression() {
        _profile[:lastWorkout] = _workoutName;
        FiveByFiveStorage.saveProfile(_profile);
        _stopAndSaveActivity();
    }

    function _notifySegmentStart() {
        if (!(Toybox has :Attention)) {
            return;
        }

        try {
            if (Attention has :vibrate) {
                Attention.vibrate([ new Attention.VibeProfile(50, 120) ]);
            }
            if (Attention has :playTone) {
                Attention.playTone(Attention.TONE_START);
            }
        } catch (ex) {
        }
    }

    function _notifySegmentEnd() {
        if (!(Toybox has :Attention)) {
            return;
        }

        try {
            if (Attention has :vibrate) {
                Attention.vibrate([ new Attention.VibeProfile(50, 120) ]);
            }
            if (Attention has :playTone) {
                Attention.playTone(Attention.TONE_STOP);
            }
        } catch (ex) {
        }
    }

    function _isWorkoutSegmentState(state) {
        return (state == FiveByFiveState.REST || state == FiveByFiveState.WORK);
    }

    function _effectiveSettingsBaseState() {
        if (_stateBeforeSettings != null) {
            return _stateBeforeSettings;
        }
        if (_currentExercise() != null) {
            return FiveByFiveState.REST;
        }
        return FiveByFiveState.SUMMARY;
    }

    function _skipCurrentSegment() {
        if (_state == FiveByFiveState.WARMUP) {
            _skippedSegments.add({
                :type => FiveByFiveState.WARMUP
            });
            _notifySegmentEnd();
            _recordLap();
            _enterSegment(FiveByFiveState.REST);
            return;
        }

        if (_state == FiveByFiveState.REST || _state == FiveByFiveState.WORK) {
            // Skipping in a workout segment skips the entire exercise block (all remaining sets).
            _skippedSegments.add({
                :type => :EXERCISE,
                :exerciseIndex => _exerciseIndex
            });

            _notifySegmentEnd();
            _recordLap();

            if ((_exerciseIndex + 1) < _plan.size()) {
                _exerciseIndex += 1;
                _setIndex = 0;
                _enterSegment(FiveByFiveState.REST);
                return;
            }

            _gotoEndOrSkippedPrompt();
        }
    }

    function _gotoEndOrSkippedPrompt() {
        if (_skippedSegments.size() > 0) {
            _skippedPromptCursor = 0;
            _transitionTo(FiveByFiveState.SKIPPED_PROMPT);
            return;
        }

        _summaryElapsedMs = System.getTimer() - _sessionStartMs;
        if (_summaryElapsedMs < 0) {
            _summaryElapsedMs = 0;
        }
        _transitionTo(FiveByFiveState.SUMMARY);
    }

    function _startMakeup() {
        if (_skippedSegments.size() == 0) {
            _gotoEndOrSkippedPrompt();
            return;
        }

        _makeupIndex = 0;
        _enterSegment(FiveByFiveState.MAKEUP);
    }

    function _currentMakeupText() {
        if (_makeupIndex >= _skippedSegments.size()) {
            return "";
        }

        var item = _skippedSegments[_makeupIndex];
        var t = item[:type];
        if (t == FiveByFiveState.WARMUP) {
            return "Warmup";
        }

        if (t == :EXERCISE) {
            var ex = _plan[item[:exerciseIndex]];
            if (ex == null) {
                return "Exercise";
            }
            return ex[:name] + " (all sets)";
        }

        return "Segment";
    }

    function _finishOneMakeup() {
        _notifySegmentEnd();
        _recordLap();

        _makeupIndex += 1;
        if (_makeupIndex >= _skippedSegments.size()) {
            _skippedSegments = [];
            _gotoEndOrSkippedPrompt();
            return;
        }

        _enterSegment(FiveByFiveState.MAKEUP);
    }

    function _formatDuration(ms) {
        if (ms == null) {
            ms = 0;
        }
        if (ms < 0) {
            ms = 0;
        }

        var totalSec = (ms / 1000).toNumber();
        var minutes = (totalSec / 60).toNumber();
        var seconds = (totalSec % 60).toNumber();
        return minutes.format("%02d") + ":" + seconds.format("%02d");
    }

    function _resumeElapsedIfFrozen() {
        if (_frozenElapsedMs != null) {
            _segmentStartMs = System.getTimer() - _frozenElapsedMs;
            _frozenElapsedMs = null;
        }
    }

    function onLap() {
        if (_weightEditOpen) {
            _setCurrentWeight(_weightEditValue);
            FiveByFiveStorage.saveProfile(_profile);
            _weightEditOpen = false;
            return;
        }

        if (_state == FiveByFiveState.SELECT_WORKOUT) {
            _workoutName = (_workoutCursor == 0) ? "A" : "B";
            _buildPlanForWorkout();
            _transitionTo(FiveByFiveState.WORKOUT_PREVIEW);
            return;
        }

        if (_state == FiveByFiveState.WORKOUT_PREVIEW) {
            _transitionTo(FiveByFiveState.ASK_WARMUP);
            return;
        }

        if (_state == FiveByFiveState.ASK_WARMUP) {
            _summaryElapsedMs = null;

            if (_warmupCursor == 0) {
                _warmupStarted = false;
                _transitionTo(FiveByFiveState.WARMUP);
            } else {
                _startActivitySessionIfNeeded();
                _sessionStarted = true;
                _sessionStartMs = System.getTimer();
                _enterSegment(FiveByFiveState.REST);
            }
            return;
        }

        if (_state == FiveByFiveState.WARMUP) {
            if (!_warmupStarted) {
                _startActivitySessionIfNeeded();
                _sessionStarted = true;
                _sessionStartMs = System.getTimer();
                _warmupStarted = true;
                _enterSegment(FiveByFiveState.WARMUP);
                return;
            }

            _notifySegmentEnd();
            _recordLap();
            _warmupStarted = false;
            _enterSegment(FiveByFiveState.REST);
            return;
        }

        if (_state == FiveByFiveState.REST) {
            _notifySegmentEnd();
            _recordLap();
            _enterSegment(FiveByFiveState.WORK);
            return;
        }

        if (_state == FiveByFiveState.WORK) {
            _notifySegmentEnd();
            _recordLap();

            var ex = _currentExercise();
            if (ex == null) {
                _gotoEndOrSkippedPrompt();
                return;
            }

            var totalSets = ex[:sets].toNumber();
            if ((_setIndex + 1) < totalSets) {
                _setIndex += 1;
                _enterSegment(FiveByFiveState.REST);
                return;
            }

            _freezeElapsed();
            _choiceCursor = 0;
            _state = FiveByFiveState.CHOICE;
            return;
        }

        if (_state == FiveByFiveState.CHOICE) {
            var exChoice = _currentExercise();
            if (exChoice != null) {
                _exerciseEasyMap[exChoice[:name]] = (_choiceCursor == 0);
            }

            if ((_exerciseIndex + 1) < _plan.size()) {
                _exerciseIndex += 1;
                _setIndex = 0;
                _enterSegment(FiveByFiveState.REST);
            } else {
                _gotoEndOrSkippedPrompt();
            }
            return;
        }

        if (_state == FiveByFiveState.SETTINGS) {
            var baseState = _effectiveSettingsBaseState();
            var options = _settingsOptions();
            if (options.size() == 0) {
                _state = baseState;
                _resumeElapsedIfFrozen();
                return;
            }

            if (_settingsCursor >= options.size()) {
                _settingsCursor = 0;
            }

            var selected = options[_settingsCursor];
            if (selected == "Resume" || _settingsCursor == (options.size() - 1)) {
                _state = baseState;
                _resumeElapsedIfFrozen();
                return;
            }

            if (selected == "Edit weight" || (_settingsCursor == 0 && _isWorkoutSegmentState(baseState))) {
                _state = baseState;
                _resumeElapsedIfFrozen();
                if (_isWorkoutSegmentState(baseState)) {
                    _weightEditOpen = true;
                    _weightEditValue = _currentWeight();
                }
                return;
            }

            if (selected == "Skip segment"
                || (_settingsCursor == 0 && baseState == FiveByFiveState.WARMUP)
                || (_settingsCursor == 1 && _isWorkoutSegmentState(baseState))) {
                _state = baseState;
                _resumeElapsedIfFrozen();
                if (_isWorkoutSegmentState(baseState) || baseState == FiveByFiveState.WARMUP) {
                    _skipCurrentSegment();
                }
                return;
            }
        }

        if (_state == FiveByFiveState.EXIT_PROMPT) {
            if (_exitPromptCursor == 0) {
                _state = _stateBeforeExitPrompt;
                _stateBeforeExitPrompt = null;
                if (_frozenElapsedMs != null) {
                    _segmentStartMs = System.getTimer() - _frozenElapsedMs;
                }
                _frozenElapsedMs = null;
                return;
            }

            if (_exitPromptCursor == 1) {
                _saveSessionWithoutProgression();
                _transitionTo(FiveByFiveState.EXIT);
                return;
            }

            _stopAndDiscardActivity();
            _transitionTo(FiveByFiveState.EXIT);
            return;
        }

        if (_state == FiveByFiveState.SKIPPED_PROMPT) {
            if (_skippedPromptCursor == 0) {
                _startMakeup();
                return;
            }

            _summaryElapsedMs = System.getTimer() - _sessionStartMs;
            if (_summaryElapsedMs < 0) {
                _summaryElapsedMs = 0;
            }
            _transitionTo(FiveByFiveState.SUMMARY);
            return;
        }

        if (_state == FiveByFiveState.MAKEUP) {
            _finishOneMakeup();
            return;
        }

        if (_state == FiveByFiveState.SUMMARY) {
            _saveCompletedSession();
            _transitionTo(FiveByFiveState.EXIT);
            return;
        }
    }

    function _settingsOptions() {
        var baseState = _effectiveSettingsBaseState();
        var options = ["Resume"];

        if (_isWorkoutSegmentState(baseState)) {
            options = ["Edit weight", "Skip segment", "Resume"];
        } else if (baseState == FiveByFiveState.WARMUP) {
            options = ["Skip segment", "Resume"];
        }

        return options;
    }

    function onUpPress() {
        if (_weightEditOpen) {
            _weightEditValue += WEIGHT_EDIT_STEP;
            return;
        }

        if (_state == FiveByFiveState.SELECT_WORKOUT) {
            _workoutCursor = (_workoutCursor == 0) ? 1 : 0;
            return;
        }

        if (_state == FiveByFiveState.WORKOUT_PREVIEW) {
            if (_previewScroll > 0) {
                _previewScroll -= 1;
            }
            return;
        }

        if (_state == FiveByFiveState.ASK_WARMUP) {
            _warmupCursor = (_warmupCursor == 0) ? 1 : 0;
            return;
        }

        if (_state == FiveByFiveState.CHOICE) {
            _choiceCursor = (_choiceCursor == 0) ? 1 : 0;
            return;
        }

        if (_state == FiveByFiveState.EXIT_PROMPT) {
            if (_exitPromptCursor == 0) {
                _exitPromptCursor = 2;
            } else {
                _exitPromptCursor -= 1;
            }
            return;
        }

        if (_state == FiveByFiveState.SKIPPED_PROMPT) {
            _skippedPromptCursor = (_skippedPromptCursor == 0) ? 1 : 0;
            return;
        }

        if (_state == FiveByFiveState.SETTINGS) {
            var options = _settingsOptions();
            if (options.size() > 0) {
                if (_settingsCursor == 0) {
                    _settingsCursor = options.size() - 1;
                } else {
                    _settingsCursor -= 1;
                }
            }
            return;
        }

        if (_sessionStarted && _state != FiveByFiveState.CLOCK) {
            _stateBeforeClock = _state;
            _freezeElapsed();
            _state = FiveByFiveState.CLOCK;
        }
    }

    function onDownPress() {
        if (_weightEditOpen) {
            _weightEditValue -= WEIGHT_EDIT_STEP;
            if (_weightEditValue < 0.0) {
                _weightEditValue = 0.0;
            }
            return;
        }

        if (_state == FiveByFiveState.CLOCK) {
            if (_stateBeforeClock != null) {
                _state = _stateBeforeClock;
                _stateBeforeClock = null;
                if (_frozenElapsedMs != null) {
                    _segmentStartMs = System.getTimer() - _frozenElapsedMs;
                }
                _frozenElapsedMs = null;
            }
            return;
        }

        if (_state == FiveByFiveState.WORKOUT_PREVIEW) {
            var maxScroll = _programPreviewMaxScroll();
            if (_previewScroll < maxScroll) {
                _previewScroll += 1;
            }
            return;
        }

        if (_state == FiveByFiveState.EXIT_PROMPT) {
            _exitPromptCursor = (_exitPromptCursor + 1) % 3;
            return;
        }

        if (_state == FiveByFiveState.SKIPPED_PROMPT) {
            _skippedPromptCursor = (_skippedPromptCursor == 0) ? 1 : 0;
            return;
        }

        if (_state == FiveByFiveState.SETTINGS) {
            var options2 = _settingsOptions();
            if (options2.size() > 0) {
                _settingsCursor = (_settingsCursor + 1) % options2.size();
            }
            return;
        }

        if (_state == FiveByFiveState.SELECT_WORKOUT || _state == FiveByFiveState.ASK_WARMUP || _state == FiveByFiveState.CHOICE) {
            onUpPress();
        }
    }

    function onBackPress() {
        if (!_sessionStarted) {
            return false;
        }

        if (_state == FiveByFiveState.SETTINGS) {
            _state = _effectiveSettingsBaseState();
            _stateBeforeSettings = null;
            if (_frozenElapsedMs != null) {
                _segmentStartMs = System.getTimer() - _frozenElapsedMs;
            }
            _frozenElapsedMs = null;
            return true;
        }

        if (_state == FiveByFiveState.EXIT_PROMPT) {
            _state = _stateBeforeExitPrompt;
            _stateBeforeExitPrompt = null;
            if (_frozenElapsedMs != null) {
                _segmentStartMs = System.getTimer() - _frozenElapsedMs;
            }
            _frozenElapsedMs = null;
            return true;
        }

        _weightEditOpen = false;
        _stateBeforeExitPrompt = _state;
        _exitPromptCursor = 0;
        _freezeElapsed();
        _state = FiveByFiveState.EXIT_PROMPT;
        return true;
    }

    function onUpHold() {
        if (_weightEditOpen) {
            return;
        }

        if (_sessionStarted && (_isWorkoutSegmentState(_state) || _state == FiveByFiveState.WARMUP)) {
            _stateBeforeSettings = _state;
            _settingsCursor = 0;
            _freezeElapsed();
            _state = FiveByFiveState.SETTINGS;
        }
    }

    function _formatElapsed() {
        if (_state == FiveByFiveState.CLOCK) {
            return "";
        }

        var elapsedMs = _frozenElapsedMs;
        if (elapsedMs == null) {
            elapsedMs = System.getTimer() - _segmentStartMs;
            if (elapsedMs < 0) {
                elapsedMs = 0;
            }
        }

        return _formatDuration(elapsedMs);
    }

    function _clockText() {
        var clock = System.getClockTime();
        return clock.hour.format("%02d") + ":" + clock.min.format("%02d");
    }

    function _segmentLabel() {
        if (_state == FiveByFiveState.SELECT_WORKOUT) {
            return "Select Workout";
        }

        if (_state == FiveByFiveState.WORKOUT_PREVIEW) {
            return "Workout " + _workoutName;
        }

        if (_state == FiveByFiveState.ASK_WARMUP) {
            return "Warmup?";
        }

        if (_state == FiveByFiveState.WARMUP) {
            return "Warmup";
        }

        if (_state == FiveByFiveState.REST) {
            return "Rest";
        }

        if (_state == FiveByFiveState.WORK || _state == FiveByFiveState.CHOICE) {
            var ex = _currentExercise();
            if (ex == null) {
                return "";
            }
            return ex[:name] + " " + (_setIndex + 1).format("%d") + "/" + ex[:sets].format("%d");
        }

        if (_state == FiveByFiveState.SETTINGS) {
            return "Settings";
        }

        if (_state == FiveByFiveState.CLOCK) {
            return "Current Time";
        }

        if (_state == FiveByFiveState.EXIT_PROMPT) {
            return "End Session";
        }

        if (_state == FiveByFiveState.SKIPPED_PROMPT) {
            return "Skipped Segments";
        }

        if (_state == FiveByFiveState.MAKEUP) {
            return "Makeup";
        }

        if (_state == FiveByFiveState.SUMMARY) {
            return "Workout completed";
        }

        if (_state == FiveByFiveState.ACTIVITY_SAVE) {
            return "Saving...";
        }

        if (_state == FiveByFiveState.EXIT) {
            return "Saved";
        }

        return "";
    }

    function _currentWeightText() {
        if (_state == FiveByFiveState.REST) {
            var exRest = _currentExercise();
            if (exRest == null) {
                return "";
            }
            return exRest[:name] + " " + (_setIndex + 1).format("%d") + "/" + exRest[:sets].format("%d");
        }

        if (_state == FiveByFiveState.WORK || _state == FiveByFiveState.CHOICE) {
            return FiveByFiveWorkoutLogic.formatWeightKg(_currentWeight());
        }
        return "";
    }

    function _valueLabel() {
        if (_state == FiveByFiveState.REST) {
            return "Next";
        }

        if (_state == FiveByFiveState.WORK || _state == FiveByFiveState.CHOICE) {
            return "Weight";
        }
        return "";
    }

    function _showValueRow() {
        return (_state == FiveByFiveState.REST || _state == FiveByFiveState.WORK || _state == FiveByFiveState.CHOICE);
    }

    function _showSelectionRow() {
        return (_state == FiveByFiveState.SELECT_WORKOUT || _state == FiveByFiveState.ASK_WARMUP);
    }

    function _programPreviewLines() {
        var lines = [];

        if (_workoutName == null) {
            return lines;
        }

        for (var i = 0; i < _plan.size(); i += 1) {
            var ex = _plan[i];
            var weights = _profile[:weights];
            var value = weights[ex[:name]];
            if (value == null) {
                value = 0.0;
            }
            var formattedWeight = FiveByFiveWorkoutLogic.formatWeightKg(value.toFloat());
            lines.add(ex[:sets].format("%d") + "x " + ex[:name] + " (" + formattedWeight + ")");
        }

        return lines;
    }

    function _programPreviewMaxScroll() {
        var lines = _programPreviewLines();
        var maxVisible = 3;
        if (lines.size() <= maxVisible) {
            return 0;
        }
        return lines.size() - maxVisible;
    }

    function _selectionOptions() {
        if (_state == FiveByFiveState.SELECT_WORKOUT) {
            return ["A", "B"];
        }

        if (_state == FiveByFiveState.ASK_WARMUP) {
            return ["Yes", "No"];
        }

        return [];
    }

    function _selectionCursor() {
        if (_state == FiveByFiveState.SELECT_WORKOUT) {
            return _workoutCursor;
        }

        if (_state == FiveByFiveState.ASK_WARMUP) {
            return _warmupCursor;
        }

        return 0;
    }

    function _nextText() {
        if (_state == FiveByFiveState.WARMUP) {
            return _warmupStarted ? "LAP to end warmup" : "LAP to start warmup";
        }

        if (_state == FiveByFiveState.REST) {
            return FiveByFiveWorkoutLogic.formatWeightKg(_currentWeight());
        }

        if (_state == FiveByFiveState.CHOICE) {
            return "Set complete";
        }

        if (_state == FiveByFiveState.SKIPPED_PROMPT) {
            return "Perform skipped now?";
        }

        if (_state == FiveByFiveState.MAKEUP) {
            return _currentMakeupText();
        }

        if (_state == FiveByFiveState.SUMMARY) {
            return "Total " + _formatDuration(_summaryElapsedMs);
        }

        return "";
    }

    function _showNextRow() {
        return (_nextText() != ""
            && _state != FiveByFiveState.WORK
            && _state != FiveByFiveState.CLOCK
            && _state != FiveByFiveState.WORKOUT_PREVIEW);
    }

    function _showNextHeader() {
        return (_state != FiveByFiveState.SELECT_WORKOUT
            && _state != FiveByFiveState.WORKOUT_PREVIEW
            && _state != FiveByFiveState.ASK_WARMUP
            && _state != FiveByFiveState.WARMUP
            && _state != FiveByFiveState.REST
            && _state != FiveByFiveState.SUMMARY
            && _state != FiveByFiveState.SKIPPED_PROMPT);
    }

    function _hintText() {
        if (_weightEditOpen) {
            return "UP/DOWN +/- 2.5, LAP save";
        }

        if (_state == FiveByFiveState.SELECT_WORKOUT || _state == FiveByFiveState.ASK_WARMUP) {
            return "LAP confirm option";
        }

        if (_state == FiveByFiveState.WORKOUT_PREVIEW) {
            return "LAP to continue";
        }

        if (_state == FiveByFiveState.REST || _state == FiveByFiveState.WORK || _state == FiveByFiveState.WARMUP) {
            return "Hold UP for settings";
        }

        if (_state == FiveByFiveState.CLOCK) {
            return "DOWN return";
        }

        if (_state == FiveByFiveState.CHOICE
            || _state == FiveByFiveState.SETTINGS
            || _state == FiveByFiveState.EXIT_PROMPT
            || _state == FiveByFiveState.SKIPPED_PROMPT) {
            return "LAP confirm option";
        }

        if (_state == FiveByFiveState.SUMMARY) {
            return "LAP save activity";
        }

        return "";
    }

    function _overlayTitle() {
        if (_weightEditOpen) {
            return "Edit Weight";
        }

        if (_state == FiveByFiveState.CHOICE) {
            return "Perceived Effort";
        }

        if (_state == FiveByFiveState.SETTINGS) {
            return "Settings";
        }

        if (_state == FiveByFiveState.EXIT_PROMPT) {
            return "Session Options";
        }

        if (_state == FiveByFiveState.SKIPPED_PROMPT) {
            return "Skipped Segments";
        }

        return "";
    }

    function _overlayOptions() {
        if (_weightEditOpen) {
            return [FiveByFiveWorkoutLogic.formatWeightKg(_weightEditValue)];
        }

        if (_state == FiveByFiveState.CHOICE) {
            return ["Easy", "Hard"];
        }

        if (_state == FiveByFiveState.SETTINGS) {
            return _settingsOptions();
        }

        if (_state == FiveByFiveState.EXIT_PROMPT) {
            return ["Resume", "Save", "Delete"];
        }

        if (_state == FiveByFiveState.SKIPPED_PROMPT) {
            return ["Do skipped", "Finish now"];
        }

        return [];
    }

    function _overlayCursor() {
        if (_state == FiveByFiveState.CHOICE) {
            return _choiceCursor;
        }

        if (_state == FiveByFiveState.SETTINGS) {
            return _settingsCursor;
        }

        if (_state == FiveByFiveState.EXIT_PROMPT) {
            return _exitPromptCursor;
        }

        if (_state == FiveByFiveState.SKIPPED_PROMPT) {
            return _skippedPromptCursor;
        }

        return 0;
    }

    function isOverlayVisible() {
        return _weightEditOpen
            || (_state == FiveByFiveState.CHOICE)
            || (_state == FiveByFiveState.EXIT_PROMPT)
            || (_state == FiveByFiveState.SKIPPED_PROMPT);
    }

    function getDisplayModel() {
        return {
            :segment => _segmentLabel(),
            :elapsed => _formatElapsed(),
            :showElapsed => (_state != FiveByFiveState.SELECT_WORKOUT
                && _state != FiveByFiveState.WORKOUT_PREVIEW
                && _state != FiveByFiveState.ASK_WARMUP
                && (_state != FiveByFiveState.WARMUP || _warmupStarted)
                && _state != FiveByFiveState.SUMMARY
                && _state != FiveByFiveState.CLOCK),
            :showValue => _showValueRow(),
            :valueLabel => _valueLabel(),
            :weight => _currentWeightText(),
            :showSelection => _showSelectionRow(),
            :selectionOptions => _selectionOptions(),
            :selectionCursor => _selectionCursor(),
            :showProgramPreview => (_state == FiveByFiveState.WORKOUT_PREVIEW),
            :programPreviewLines => _programPreviewLines(),
            :programPreviewScroll => _previewScroll,
            :showNext => _showNextRow(),
            :showNextHeader => _showNextHeader(),
            :next => _nextText(),
            :isWorkOrRest => (_state == FiveByFiveState.WORK
                || _state == FiveByFiveState.REST
                || _state == FiveByFiveState.CHOICE),
            :isSummary => (_state == FiveByFiveState.SUMMARY),
            :showClock => (_state == FiveByFiveState.CLOCK),
            :clockText => _clockText(),
            :showSettings => (_state == FiveByFiveState.SETTINGS),
            :settingsOptions => _settingsOptions(),
            :settingsCursor => _settingsCursor,
            :hint => _hintText(),
            :weightEditOpen => _weightEditOpen,
            :overlayVisible => isOverlayVisible(),
            :overlayTitle => _overlayTitle(),
            :overlayOptions => _overlayOptions(),
            :overlayCursor => _overlayCursor()
        };
    }
}
