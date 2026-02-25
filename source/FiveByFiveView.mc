using Toybox.Graphics;
using Toybox.Timer;
using Toybox.WatchUi;

class FiveByFiveMainView extends WatchUi.View {
    var _machine;
    var _timer;

    function initialize() {
        View.initialize();
        _machine = new FiveByFiveStateMachine();
        _timer = new Timer.Timer();
    }

    function onShow() {
        _timer.start(method(:_onTick), 1000, true);
    }

    function onHide() {
        _timer.stop();
    }

    function _onTick() {
        WatchUi.requestUpdate();
    }

    function onUpdate(dc) {
        var model = _machine.getDisplayModel();

        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        var w = dc.getWidth();
        var h = dc.getHeight();
        var cx = w / 2;
        var yScale = h.toFloat() / 240.0;
        var centerShift = (h > 280) ? ((h - 240) / 4).toNumber() : 0;
        var workoutRestShift = model[:isWorkOrRest] ? (18 * yScale).toNumber() : 0;
        var segmentFont = model[:isWorkOrRest] ? Graphics.FONT_MEDIUM : Graphics.FONT_SMALL;
        var lineStep = (24 * yScale).toNumber();
        var topInset = (10 * yScale).toNumber();
        var elapsedY = topInset + centerShift + workoutRestShift;
        var headingY = (model[:showElapsed] ? (30 * yScale).toNumber() : (24 * yScale).toNumber()) + centerShift + workoutRestShift;
        var selectionStartY = (74 * yScale).toNumber() + centerShift;
        var valueLabelY = (72 * yScale).toNumber() + centerShift + workoutRestShift;
        var valueY = (88 * yScale).toNumber() + centerShift + workoutRestShift;
        var nextHeaderY = (114 * yScale).toNumber() + centerShift + workoutRestShift;
        var nextY = (130 * yScale).toNumber() + centerShift + workoutRestShift;
        var hintBottomInset = (56 * yScale).toNumber();
        var hintY = h - hintBottomInset;

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);

        if (model[:showClock]) {
            dc.drawText(cx, (72 * yScale).toNumber() + centerShift, Graphics.FONT_XTINY, model[:segment], Graphics.TEXT_JUSTIFY_CENTER);
            dc.drawText(cx, (106 * yScale).toNumber() + centerShift, Graphics.FONT_MEDIUM, model[:clockText], Graphics.TEXT_JUSTIFY_CENTER);
            if (model[:hint] != "") {
                dc.drawText(cx, h - hintBottomInset, Graphics.FONT_XTINY, model[:hint], Graphics.TEXT_JUSTIFY_CENTER);
            }
            return;
        }

        if (model[:showSettings]) {
            dc.drawText(cx, (52 * yScale).toNumber() + centerShift, Graphics.FONT_SMALL, "Settings", Graphics.TEXT_JUSTIFY_CENTER);
            var options = model[:settingsOptions];
            var cursor = model[:settingsCursor].toNumber();
            for (var si = 0; si < options.size(); si += 1) {
                var sy = (86 * yScale).toNumber() + centerShift + (si * lineStep);
                var sprefix = (si == cursor) ? "> " : "  ";
                dc.drawText(cx, sy, Graphics.FONT_TINY, sprefix + options[si], Graphics.TEXT_JUSTIFY_CENTER);
            }
            if (model[:hint] != "") {
                dc.drawText(cx, h - hintBottomInset, Graphics.FONT_XTINY, model[:hint], Graphics.TEXT_JUSTIFY_CENTER);
            }
            return;
        }

        if (model[:showElapsed]) {
            dc.drawText(cx, elapsedY, Graphics.FONT_TINY, model[:elapsed], Graphics.TEXT_JUSTIFY_CENTER);
        }

        if (model[:isSummary]) {
            headingY = (h / 2) - (16 * yScale).toNumber();
            valueLabelY = headingY + (36 * yScale).toNumber();
            valueY = valueLabelY + (16 * yScale).toNumber();
        }

        dc.drawText(cx, headingY, segmentFont, model[:segment], Graphics.TEXT_JUSTIFY_CENTER);

        if (model[:showSelection]) {
            var options = model[:selectionOptions];
            var cursor = model[:selectionCursor].toNumber();
            for (var i = 0; i < options.size(); i += 1) {
                var rowY = selectionStartY + (i * lineStep);
                var prefix = (i == cursor) ? "> " : "  ";
                dc.drawText(cx, rowY, Graphics.FONT_TINY, prefix + options[i], Graphics.TEXT_JUSTIFY_CENTER);
            }
        }

        if (model[:showProgramPreview]) {
            var previewLines = model[:programPreviewLines];
            var previewOffset = model[:programPreviewScroll].toNumber();
            var previewStartY = (68 * yScale).toNumber() + centerShift;
            var previewLineStep = (20 * yScale).toNumber();
            var maxVisible = 3;
            for (var pi = 0; pi < maxVisible; pi += 1) {
                var idx = previewOffset + pi;
                if (idx >= previewLines.size()) {
                    break;
                }
                dc.drawText(cx, previewStartY + (pi * previewLineStep), Graphics.FONT_TINY, previewLines[idx], Graphics.TEXT_JUSTIFY_CENTER);
            }
        }

        var hasValueRow = model[:showValue] && model[:valueLabel] != "";
        if (hasValueRow) {
            dc.drawText(cx, valueLabelY, Graphics.FONT_XTINY, model[:valueLabel], Graphics.TEXT_JUSTIFY_CENTER);
            dc.drawText(cx, valueY, Graphics.FONT_SMALL, model[:weight], Graphics.TEXT_JUSTIFY_CENTER);
        } else if (model[:showNext]) {
            if (model[:showNextHeader]) {
                dc.drawText(cx, valueLabelY, Graphics.FONT_XTINY, "Next", Graphics.TEXT_JUSTIFY_CENTER);
            }
            dc.drawText(cx, valueY, Graphics.FONT_SMALL, model[:next], Graphics.TEXT_JUSTIFY_CENTER);
        }

        if (model[:showNext] && hasValueRow) {
            if (model[:showNextHeader]) {
                dc.drawText(cx, nextHeaderY, Graphics.FONT_XTINY, "Next", Graphics.TEXT_JUSTIFY_CENTER);
            }
            dc.drawText(cx, nextY, Graphics.FONT_TINY, model[:next], Graphics.TEXT_JUSTIFY_CENTER);
        }

        if (model[:hint] != "") {
            if (model[:showValue] && model[:valueLabel] == "Weight") {
                hintY = (104 * yScale).toNumber();
            }
            dc.drawText(cx, hintY, Graphics.FONT_XTINY, model[:hint], Graphics.TEXT_JUSTIFY_CENTER);
        }

        if (model[:overlayVisible]) {
            _drawOverlay(dc, model);
        }
    }

    function _drawOverlay(dc, model) {
        var w = dc.getWidth();
        var h = dc.getHeight();
        var yScale = h.toFloat() / 240.0;

        var boxW = w - (30 * yScale).toNumber();
        var boxH = (110 * yScale).toNumber();
        var x = (w - boxW) / 2;
        var y = (h - boxH) / 2;
        var titleY = y + (8 * yScale).toNumber();
        var optionsStartY = y + (34 * yScale).toNumber();
        var optionStep = (24 * yScale).toNumber();

        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_DK_GRAY);
        dc.fillRectangle(x, y, boxW, boxH);

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawRectangle(x, y, boxW, boxH);
        dc.drawText(w / 2, titleY, Graphics.FONT_XTINY, model[:overlayTitle], Graphics.TEXT_JUSTIFY_CENTER);

        var options = model[:overlayOptions];
        var cursor = model[:overlayCursor].toNumber();

        if (model[:weightEditOpen]) {
            dc.drawText(w / 2, y + (34 * yScale).toNumber(), Graphics.FONT_SMALL, "+", Graphics.TEXT_JUSTIFY_CENTER);
            dc.drawText(w / 2, y + (56 * yScale).toNumber(), Graphics.FONT_SMALL, options[0], Graphics.TEXT_JUSTIFY_CENTER);
            dc.drawText(w / 2, y + (78 * yScale).toNumber(), Graphics.FONT_SMALL, "-", Graphics.TEXT_JUSTIFY_CENTER);
            return;
        }

        for (var i = 0; i < options.size(); i += 1) {
            var rowY = optionsStartY + (i * optionStep);
            var prefix = "  ";
            if (i == cursor && options.size() > 1) {
                prefix = "> ";
            }
            dc.drawText(w / 2, rowY, Graphics.FONT_XTINY, prefix + options[i], Graphics.TEXT_JUSTIFY_CENTER);
        }
    }

    function _afterInput() {
        if (_machine.shouldExit()) {
            WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
            return;
        }
        WatchUi.requestUpdate();
    }

    function handleLapPress() {
        _machine.onLap();
        _afterInput();
    }

    function handleUpPress() {
        _machine.onUpPress();
        _afterInput();
    }

    function handleDownPress() {
        _machine.onDownPress();
        _afterInput();
    }

    function handleBackPress() {
        var consumed = _machine.onBackPress();
        if (consumed) {
            _afterInput();
        }
        return consumed;
    }

    function handleUpHold() {
        _machine.onUpHold();
        _afterInput();
    }
}
