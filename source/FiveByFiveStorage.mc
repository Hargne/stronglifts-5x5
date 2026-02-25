using Toybox.Application;
using Toybox.Lang as Lang;

module FiveByFiveStorage {
    const PROFILE_KEY = "five_by_five_profile_v1";
    const LEGACY_PROFILE_KEY = "stronglifts_5x5_profile_v1";

    function _defaultWeights() {
        return {
            "Squat" => 20.0,
            "Bench Press" => 20.0,
            "Barbell Row" => 20.0,
            "Overhead Press" => 20.0,
            "Deadlift" => 40.0
        };
    }

    function defaultProfile() {
        return {
            :lastWorkout => null,
            :weights => _defaultWeights()
        };
    }

    function loadProfile() {
        var profile = defaultProfile();
        var saved = Application.Storage.getValue(PROFILE_KEY);
        if (!(saved instanceof Lang.Dictionary)) {
            // Backward compatibility: preserve existing user data from the old app key.
            saved = Application.Storage.getValue(LEGACY_PROFILE_KEY);
        }

        if (!(saved instanceof Lang.Dictionary)) {
            return profile;
        }

        var savedProfile = saved as Lang.Dictionary;

        var savedLastWorkout = savedProfile["lastWorkout"];
        if (savedLastWorkout == null) {
            savedLastWorkout = savedProfile[:lastWorkout];
        }
        if (savedLastWorkout != null) {
            profile[:lastWorkout] = savedLastWorkout;
        }

        var savedWeights = savedProfile["weights"];
        if (savedWeights == null) {
            savedWeights = savedProfile[:weights];
        }
        if (savedWeights instanceof Lang.Dictionary) {
            savedWeights = savedWeights as Lang.Dictionary;
            var merged = _defaultWeights();
            var exerciseNames = merged.keys();
            for (var i = 0; i < exerciseNames.size(); i += 1) {
                var exerciseName = exerciseNames[i];
                if (savedWeights[exerciseName] != null) {
                    merged[exerciseName] = savedWeights[exerciseName].toFloat();
                }
            }
            profile[:weights] = merged;
        }

        return profile;
    }

    function saveProfile(profile) {
        var payload = {
            "lastWorkout" => null,
            "weights" => {}
        };

        if (profile[:lastWorkout] != null) {
            payload["lastWorkout"] = profile[:lastWorkout];
        }

        var sourceWeights = profile[:weights];
        var payloadWeights = payload["weights"];
        var exerciseNames = _defaultWeights().keys();

        for (var i = 0; i < exerciseNames.size(); i += 1) {
            var exerciseName = exerciseNames[i];
            var value = sourceWeights[exerciseName];
            if (value != null) {
                payloadWeights[exerciseName] = value.toFloat();
            }
        }

        Application.Storage.setValue(PROFILE_KEY, payload);
    }
}
