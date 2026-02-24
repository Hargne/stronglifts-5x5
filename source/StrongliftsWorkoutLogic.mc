module StrongliftsWorkoutLogic {
    const WORKOUT_A = [
        { :name => "Squat", :sets => 5, :increment => 2.5 },
        { :name => "Bench Press", :sets => 5, :increment => 2.5 },
        { :name => "Barbell Row", :sets => 5, :increment => 2.5 }
    ];

    const WORKOUT_B = [
        { :name => "Squat", :sets => 5, :increment => 2.5 },
        { :name => "Overhead Press", :sets => 5, :increment => 2.5 },
        { :name => "Deadlift", :sets => 1, :increment => 5.0 }
    ];

    function getWorkout(workoutName) {
        var input = (workoutName == "B") ? WORKOUT_B : WORKOUT_A;
        var output = [];

        for (var i = 0; i < input.size(); i += 1) {
            var e = input[i];
            output.add({
                :name => e[:name],
                :sets => e[:sets],
                :increment => e[:increment]
            });
        }

        return output;
    }

    function getOppositeWorkout(lastWorkout) {
        if (lastWorkout == "A") {
            return "B";
        }
        return "A";
    }

    function formatWeightKg(value) {
        return value.format("%0.1f") + " kg";
    }
}
