using Engine;
using Gee;

class CreateServerView : MenuSubView
{
    private MenuTextButton? create_button;
    private TextInputControl name_text;

    protected override void load()
    {
        name_text = new TextInputControl("Player name", Environment.MAX_NAME_LENGTH);
        name_text.text = "dummy name";
        name_text.text_changed.connect(name_changed);
        add_child(name_text);
    }

    protected override void key_press(KeyArgs key)
    {
        if (key.handled)
            return;

        // Only handle keys if our buttons are visible
        if (!are_buttons_visible())
            return;

        // Check if no modifier keys are pressed
        if (key.down && key.modifiers == Modifier.NONE)
        {
            key.handled = true;

            if (key.scancode == ScanCode.C && create_button != null && create_button.enabled)
                do_finish();
            else if (key.scancode == ScanCode.B)
                do_back();
            else
                key.handled = false;
        }
    }

    protected override ArrayList<MenuTextButton>? get_menu_buttons()
    {
        ArrayList<MenuTextButton> buttons = new ArrayList<MenuTextButton>();

        create_button = new MenuTextButton("MenuButton", "Create (C)");
        create_button.clicked.connect(do_finish);
        buttons.add(create_button);

        MenuTextButton back_button = new MenuTextButton("MenuButton", "Back (B)");
        back_button.clicked.connect(do_back);
        buttons.add(back_button);

        return buttons;
    }

    protected override void load_finished()
    {
        name_changed();
    }

    protected override void set_visibility(bool visible)
    {
        name_text.visible = visible;
    }

    private void name_changed()
    {
        if (create_button != null)
            create_button.enabled = Environment.is_valid_name(name_text.text);
    }

    public string player_name { get { return name_text.text; } }
    public override string get_name() { return "Create Server"; }
}
