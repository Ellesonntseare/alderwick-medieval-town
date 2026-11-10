extends RefCounted

static func build(life: Node) -> void:
	var layer := CanvasLayer.new()
	layer.layer=10
	life.add_child(layer)
	life.hint=Label.new()
	life.hint.position=Vector2(28,395)
	life.hint.add_theme_color_override("font_shadow_color",Color.BLACK)
	life.hint.add_theme_constant_override("shadow_offset_x",2)
	life.hint.add_theme_constant_override("shadow_offset_y",2)
	layer.add_child(life.hint)
	life.talk_button=Button.new()
	life.talk_button.position=Vector2(28,425)
	life.talk_button.pressed.connect(func():
		if life.nearest:life.open_dialog(life.nearest))
	layer.add_child(life.talk_button)
	life.dialog=PanelContainer.new()
	layer.add_child(life.dialog)
	var style := StyleBoxFlat.new()
	style.bg_color=Color(0.035,0.055,0.048,0.97)
	style.border_color=Color("6d6954")
	style.border_width_left=1
	style.content_margin_left=22
	style.content_margin_right=22
	style.content_margin_top=22
	style.content_margin_bottom=20
	style.corner_radius_top_left=12
	style.corner_radius_bottom_left=12
	life.dialog.add_theme_stylebox_override("panel",style)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation",10)
	life.dialog.add_child(column)
	var header := HBoxContainer.new()
	column.add_child(header)
	life.heading=Label.new()
	life.heading.add_theme_font_size_override("font_size",23)
	life.heading.modulate=Color("efd7a8")
	life.heading.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	life.heading.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	header.add_child(life.heading)
	var close := Button.new()
	close.text="×"
	close.tooltip_text="Leave conversation [Esc]"
	close.pressed.connect(life.close_dialog)
	header.add_child(close)
	column.add_child(HSeparator.new())
	life.transcript=RichTextLabel.new()
	life.transcript.custom_minimum_size=Vector2(0,100)
	life.transcript.size_flags_vertical=Control.SIZE_EXPAND_FILL
	life.transcript.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	life.transcript.scroll_following=true
	life.transcript.add_theme_font_size_override("normal_font_size",17)
	life.transcript.add_theme_constant_override("line_separation",4)
	column.add_child(life.transcript)
	life.trade_row=HBoxContainer.new()
	column.add_child(life.trade_row)
	var trade := VBoxContainer.new()
	trade.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	life.trade_row.add_child(trade)
	life.trade_status=Label.new()
	life.trade_status.add_theme_font_size_override("font_size",14)
	trade.add_child(life.trade_status)
	var buttons := HBoxContainer.new()
	trade.add_child(buttons)
	for spec in [["Buy food · 2 coins",life.town.economy.player_buy],["Sell food · 1 coin",life.town.economy.player_sell]]:
		var button := Button.new()
		button.text=spec[0]
		button.add_theme_font_size_override("font_size",14)
		button.pressed.connect(spec[1])
		buttons.add_child(button)
	var shop := Button.new()
	shop.name = "ShopButton"
	shop.text = "Browse goods"
	shop.pressed.connect(func():
		var inventory: Node = life.town.inventory_ui
		if is_instance_valid(inventory):inventory.open_shop(is_instance_valid(life.active) and life.active.person_name == "Oren"))
	column.add_child(shop)
	shop.hide()
	life.ai.status=Label.new()
	life.ai.status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	life.ai.status.add_theme_font_size_override("font_size",14)
	life.ai.status.modulate=Color("b9c4b5")
	column.add_child(life.ai.status)
	life.ai.group_target=OptionButton.new()
	column.add_child(life.ai.group_target)
	life.ai.group_target.hide()
	if preload("res://dialogue_features.gd").ENABLED:
		life.ai.voice_input=load("res://town_voice_input.gd").new()
		life.ai.add_child(life.ai.voice_input)
		life.ai.voice_input.build(life.ai,column)
	life.entry=TextEdit.new()
	life.entry.placeholder_text="Write a message…"
	life.entry.custom_minimum_size=Vector2(0,68)
	life.entry.wrap_mode=TextEdit.LINE_WRAPPING_BOUNDARY
	life.entry.add_theme_font_size_override("font_size",17)
	life.entry.gui_input.connect(func(event: InputEvent):
		if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode==KEY_ENTER and not event.shift_pressed:
			life.send_entry()
			life.entry.accept_event())
	column.add_child(life.entry)
	var footer := HBoxContainer.new()
	column.add_child(footer)
	var help := Label.new()
	help.text="Enter to send · Shift+Enter for a new line"
	help.add_theme_font_size_override("font_size",12)
	help.modulate=Color("9fae9f")
	help.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	footer.add_child(help)
	life.ai.retry=Button.new()
	life.ai.retry.text="Retry"
	life.ai.retry.pressed.connect(life.send_entry)
	life.ai.retry.hide()
	footer.add_child(life.ai.retry)
	life.ai.submit=Button.new()
	life.ai.submit.text="Send"
	life.ai.submit.pressed.connect(life.send_entry)
	footer.add_child(life.ai.submit)
	if preload("res://mobile_runtime.gd").enabled():
		life.transcript.add_theme_font_size_override("normal_font_size",21)
		life.entry.add_theme_font_size_override("font_size",21)
		life.entry.custom_minimum_size.y=80
		help.text="Write below, then tap Send"
		for control: Button in life.dialog.find_children("*","Button",true,false):
			control.custom_minimum_size.y=maxf(control.custom_minimum_size.y,48)
	if not preload("res://dialogue_features.gd").ENABLED:
		life.entry.hide()
		footer.hide()
		life.ai.status.hide()
	life.get_viewport().size_changed.connect(life.ai.layout)
	life.ai.layout()
	life.ai.layout.call_deferred()
	life.dialog.hide()
	var focus:=preload("res://conversation_focus.gd").new();life.add_child(focus)
