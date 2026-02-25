using Toybox.Application;
using Toybox.WatchUi;

class FiveByFiveApp extends Application.AppBase {

    function initialize() {
        AppBase.initialize();
    }

    function onStart(state) {
    }

    function onStop(state) {
    }

    function getInitialView() {
        var view = new FiveByFiveMainView();
        var input = new FiveByFiveInputDelegate(view);
        return [view, input];
    }
}

function getApp() {
    return Application.getApp();
}
