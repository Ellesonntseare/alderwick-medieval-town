extends RefCounted

static func style(color: Color,border:=Color("9d7c4a"),margin:=14) -> StyleBoxFlat:
	var box:=StyleBoxFlat.new();box.bg_color=color;box.border_color=border
	box.set_border_width_all(1);box.set_corner_radius_all(3);box.set_content_margin_all(margin)
	return box

static func create() -> Theme:
	var theme:=Theme.new()
	var font:=SystemFont.new();font.font_names=PackedStringArray(["Georgia","Noto Serif","serif"])
	theme.default_font=font;theme.default_font_size=17
	for type in ["Label","Button","CheckBox","OptionButton","TabContainer","TabBar","LineEdit","SpinBox"]:
		theme.set_color("font_color",type,Color("352a20"))
		theme.set_color("font_hover_color",type,Color("6b361f"))
		theme.set_color("font_pressed_color",type,Color("fff0cd"))
		theme.set_color("font_focus_color",type,Color("352a20"))
	theme.set_color("default_color","RichTextLabel",Color("352a20"))
	theme.set_stylebox("panel","PanelContainer",style(Color("e5d3aa"),Color("785635"),22))
	theme.set_stylebox("panel","TabContainer",style(Color("efe1bf"),Color("bda479"),16))
	for type in ["Button","OptionButton"]:
		theme.set_stylebox("normal",type,style(Color("d9c294")))
		theme.set_stylebox("hover",type,style(Color("ecdbb5"),Color("785635")))
		theme.set_stylebox("pressed",type,style(Color("795333")))
		theme.set_stylebox("disabled",type,style(Color("c9bea5"),Color("b7a88c")))
		theme.set_stylebox("focus",type,style(Color(0,0,0,0),Color("73412a"),0))
	for type in ["TabContainer","TabBar"]:
		theme.set_stylebox("tab_selected",type,style(Color("efe1bf"),Color("9d7c4a"),12))
		theme.set_stylebox("tab_unselected",type,style(Color("c5a879"),Color("9d7c4a"),12))
		theme.set_color("font_selected_color",type,Color("352a20"))
		theme.set_color("font_unselected_color",type,Color("57432e"))
	theme.set_stylebox("normal","LineEdit",style(Color("f2e6ca")))
	theme.set_stylebox("background","ProgressBar",style(Color("c5b18b"),Color("ad9368"),0))
	theme.set_stylebox("fill","ProgressBar",style(Color("768153"),Color("768153"),0))
	return theme
