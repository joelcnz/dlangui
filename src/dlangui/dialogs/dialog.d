// Written in the D programming language.

/**
This module contains common Dialog implementation.


Use to create custom dialogs.

Synopsis:

----
import dlangui.dialogs.dialog;

----

Copyright: Vadim Lopatin, 2014
License:   Boost License 1.0
Authors:   Vadim Lopatin, coolreader.org@gmail.com
*/
module dlangui.dialogs.dialog;

import dlangui.core.i18n;
import dlangui.core.signals;
import dlangui.core.stdaction;
import dlangui.widgets.layouts;
import dlangui.widgets.controls;
import dlangui.widgets.winframe;
import dlangui.widgets.popup;
import dlangui.platforms.common.platform;

import std.conv;

/// dialog flag bits
enum DialogFlag : uint {
    /// dialog is modal
    Modal = 1,
    /// dialog can be resized
    Resizable = 2,
    /// dialog is show in popup widget inside current window instead of separate window
    Popup = 4,
}

/// slot to pass dialog result
interface DialogResultHandler {
	public void onDialogResult(Dialog dlg, const Action result);
}

/// base for all dialogs
class Dialog : VerticalLayout {
    protected Window _window;
    protected Window _parentWindow;
    protected PopupWidget _popup;
    protected UIString _caption;
    protected uint _flags;
    protected string _icon;

	Signal!DialogResultHandler onDialogResult;

    this(UIString caption, Window parentWindow = null, uint flags = DialogFlag.Modal) {
        super("dialog-main-widget");
        _caption = caption;
        _parentWindow = parentWindow;
        _flags = flags;
        _icon = "dlangui-logo1";
    }

    /// get icon resource id
    @property string windowIcon() {
        return _icon;
    }

    /// set icon resource id
    @property Dialog windowIcon(string iconResourceId) {
        _icon = iconResourceId;
		if (_window && _icon)
			_window.windowIcon = drawableCache.getImage(_icon);
        return this;
    }

	@property UIString windowCaption() {
		return _caption;
	}

    /// set window caption
	@property Dialog windowCaption(dstring caption) {
		_caption = caption;
		if (_window)
			_window.windowCaption = caption;
        return this;
	}

    /// get window caption
	@property Dialog windowCaption(UIString caption) {
		_caption = caption;
		if (_window)
			_window.windowCaption = caption;
        return this;
	}

    protected const(Action) [] _buttonActions;

    protected ImageTextButton _defaultButton;
    protected ImageTextButton _cancelButton;
	/// create panel with buttons based on list of actions
	Widget createButtonsPanel(const(Action) [] actions, int defaultActionIndex, int splitBeforeIndex) {
        _buttonActions = actions;
		LinearLayout res = new HorizontalLayout("buttons");
		res.layoutWidth(FILL_PARENT);
        res.layoutWeight = 0;
		for (int i = 0; i < actions.length; i++) {
			if (splitBeforeIndex == i)
				res.addChild(new HSpacer());
			const Action a = actions[i];
			string id = "btn" ~ to!string(a.id);
			ImageTextButton btn = new ImageTextButton(id, a.iconId, a.label);
			if (defaultActionIndex == i) {
				btn.setState(State.Default);
                _defaultButton = btn;
            }
            if (a.id == StandardAction.Cancel || a.id == StandardAction.No)
                _cancelButton = btn;
            btn.action = a.clone();
			res.addChild(btn);
		}
		return res;
	}

    /// Custom handling of actions
    override bool handleAction(const Action action) {
        foreach(const Action a; _buttonActions)
            if (a.id == action.id) {
                close(action);
                return true;
            }
        return false;
    }

	/// override to implement creation of dialog controls
	void init() {
	}

    /** Notify about dialog result, and then close dialog.

        If onDialogResult listener is assigned, pass action to it.

        If no onDialogResult listener, pass to owner window.

        If action is null, no result dispatching will occur.
      */
    void close(const Action action) {
        if (action) {
            if (onDialogResult.assigned)
                onDialogResult(this, action);
            else if (_parentWindow)
                _parentWindow.dispatchAction(action);
        }
        if (_popup)
            _parentWindow.removePopup(_popup);
        else
            window.close();
    }

    /// shows dialog
    void show() {
		init();
        uint wflags = 0;
        if (_flags & DialogFlag.Modal)
            wflags |= WindowFlag.Modal;
        if (_flags & DialogFlag.Resizable) {
            wflags |= WindowFlag.Resizable;
            layoutWidth = FILL_PARENT;
            layoutHeight = FILL_PARENT;
        }
        if (_flags & DialogFlag.Popup) {
            DialogFrame _frame = new DialogFrame(this, _cancelButton !is null);
            if (_cancelButton) {
                _frame.onCloseButtonClickListener = delegate(Widget w) {
                    close(_cancelButton.action);
                    return true;
                };
            }
            _popup = _parentWindow.showPopup(_frame);
            _popup.flags(PopupFlags.Modal);
        } else {
            _window = Platform.instance.createWindow(_caption, _parentWindow, wflags);
            if (_window && _icon)
                _window.windowIcon = drawableCache.getImage(_icon);
            _window.mainWidget = this;
            _window.show();
        }
        onShow();
    }

    /// called after window with dialog is shown
    void onShow() {
        // override to do something useful
        if (_defaultButton)
            _defaultButton.setFocus();
    }
}

/// frame with caption for dialog
class DialogFrame : WindowFrame {
    protected Dialog _dialog;
    this(Dialog dialog, bool enableCloseButton) {
        super(dialog.id ~ "_frame", enableCloseButton);
        _dialog = dialog;
        _caption.text = _dialog.windowCaption.value;
        bodyWidget = _dialog;
    }
}
