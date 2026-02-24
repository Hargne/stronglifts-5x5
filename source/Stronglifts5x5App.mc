using Toybox.Application;
using Toybox.WatchUi;

class Stronglifts5x5App extends Application.AppBase {

    function initialize() {
        AppBase.initialize();
    }

    function onStart(state) {
    }

    function onStop(state) {
    }

    function getInitialView() {
        var view = new StrongliftsMainView();
        var input = new StrongliftsInputDelegate(view);
        return [view, input];
    }
}

function getApp() {
    return Application.getApp();
}
