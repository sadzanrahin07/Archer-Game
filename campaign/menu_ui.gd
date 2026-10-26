extends RefCounted
# Container-driven UI: layout is measured in logical units, with safe-area margins.
var g:Node
var shell:VBoxContainer
var portrait:=false
var compact:=false
var width:=1280.0
var height:=720.0
var preview_drag:=false
var preview_distance:=0.0
var header_coin: Label = null
var font_title: FontFile = load("res://assets/ui/flat-ui/fonts/Baloo2-ExtraBold.ttf") if ResourceLoader.exists("res://assets/ui/flat-ui/fonts/Baloo2-ExtraBold.ttf") else null
var font_body: FontFile = load("res://assets/ui/flat-ui/fonts/Nunito-Bold.ttf") if ResourceLoader.exists("res://assets/ui/flat-ui/fonts/Nunito-Bold.ttf") else null
var font_semi: FontFile = load("res://assets/ui/flat-ui/fonts/Nunito-SemiBold.ttf") if ResourceLoader.exists("res://assets/ui/flat-ui/fonts/Nunito-SemiBold.ttf") else null
var font_mono: FontFile = load("res://assets/ui/flat-ui/fonts/RobotoMono-Regular.ttf") if ResourceLoader.exists("res://assets/ui/flat-ui/fonts/RobotoMono-Regular.ttf") else null

func _init(context:Node) -> void:
	g=context
	width=g.ui.size.x;height=g.ui.size.y
	portrait=false # One landscape composition on desktop, tablet and phone.
	compact=width<1000 or height<590

func begin() -> void:
	g._clear_ui()
	if g.page in ["levels","settings"]:
		var dim_bg:=ColorRect.new()
		dim_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		dim_bg.color=Color(0.02,0.05,0.04,0.60)
		dim_bg.mouse_filter=Control.MOUSE_FILTER_IGNORE
		g.ui.add_child(dim_bg)
	var margin:=MarginContainer.new();margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var insets:Vector4=g.safe_margins
	for pair in [["left",insets.x],["top",insets.y],["right",insets.z],["bottom",insets.w]]:margin.add_theme_constant_override("margin_"+pair[0],int(pair[1]))
	g.ui.add_child(margin)
	shell=VBoxContainer.new();shell.add_theme_constant_override("separation",4 if compact else 10);margin.add_child(shell)

func label(parent:Node,text:String,font_size:int=20,muted:bool=false,title_font:bool=false) -> Label:
	var node:=Label.new();node.text=text;node.autowrap_mode=TextServer.AUTOWRAP_OFF
	if title_font and font_title!=null:node.add_theme_font_override("font",font_title)
	elif font_body!=null:node.add_theme_font_override("font",font_body)
	node.add_theme_font_size_override("font_size",font_size)
	node.add_theme_color_override("font_color",FlatUiTokens.SLATE if muted else Color.WHITE)
	node.add_theme_color_override("font_outline_color",Color(0.02,0.03,0.06,0.9))
	node.add_theme_constant_override("outline_size",1)
	node.mouse_filter=Control.MOUSE_FILTER_IGNORE
	node.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	parent.add_child(node);return node

func button(parent:Node,text:String,action:Callable,primary:bool=false) -> Button:
	var node:=Button.new();node.text=text
	var min_h:float = maxf(56.0,48.0/g.ui_scale)
	node.custom_minimum_size=Vector2(0,min_h)
	node.clip_text=true;node.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS;node.tooltip_text=text
	node.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	if primary and font_title!=null:
		node.add_theme_font_override("font",font_title)
		node.add_theme_font_size_override("font_size",maxi(20,ceili(16.0/g.ui_scale)))
	elif font_body!=null:
		node.add_theme_font_override("font",font_body)
		node.add_theme_font_size_override("font_size",maxi(20,ceili(16.0/g.ui_scale)))
	else:
		node.add_theme_font_size_override("font_size",maxi(20,ceili(16.0/g.ui_scale)))
	style_button(node,"primary" if primary else "action")
	node.pressed.connect(func():g.play_sound("res://campaign/audio/click.mp3");action.call_deferred())
	parent.add_child(node);return node

func style_button(node:Button,role:String,selected:bool=false) -> void:
	for state_name in ["normal","hover","pressed","disabled","focus"]:
		var fill:=Color(0.025,0.10,0.075,0.94)
		var border:=Color(0.74,0.90,0.80,0.40)
		var ink:=Color("f1f6f3")
		var border_w:=1
		var radius:=12
		
		match role:
			"primary","select","buy","equip":
				fill = Color(0.20,0.39,0.30,0.95) if state_name=="normal" else (Color(0.25,0.47,0.36,0.98) if state_name in ["hover","focus"] else (Color(0.15,0.31,0.24,0.98) if state_name=="pressed" else Color(0.04,0.08,0.06,0.85)))
				border = Color(0.78,0.94,0.85,0.70) if state_name!="disabled" else Color(0.25,0.38,0.32,0.3)
				ink = Color("f1f6f3") if state_name!="disabled" else Color("8ba398")
				border_w = 1
				radius = 14
			"upgrade":
				fill = Color(0.20,0.39,0.30,0.95) if state_name=="normal" else (Color(0.25,0.47,0.36,0.98) if state_name in ["hover","focus"] else (Color(0.15,0.31,0.24,0.98) if state_name=="pressed" else Color(0.04,0.08,0.06,0.85)))
				border = Color(0.78,0.94,0.85,0.70) if state_name!="disabled" else Color(0.25,0.38,0.32,0.3)
				ink = Color("f1f6f3") if state_name!="disabled" else Color("8ba398")
				border_w = 1
				radius = 14
			"equipped":
				fill = Color(0.05,0.14,0.10,0.90)
				border = Color(0.50,0.75,0.65,0.50)
				ink = Color("a8d5b8")
				border_w = 1
				radius = 14
			"tab":
				if selected:
					fill = Color(0.20,0.39,0.30,0.95)
					border = Color(0.78,0.94,0.85,0.70)
					ink = Color("f1f6f3")
					border_w = 1
				else:
					fill = Color(0.025,0.10,0.075,0.94) if state_name=="normal" else (Color(0.04,0.14,0.10,0.96) if state_name in ["hover","focus"] else Color(0.02,0.06,0.04,0.9))
					border = Color(0.74,0.90,0.80,0.35) if state_name=="normal" else Color(0.78,0.94,0.85,0.55)
					ink = Color("c7dad1") if state_name=="normal" else Color("f1f6f3")
					border_w = 1
				radius = 12
			"nav":
				fill = Color(0.025,0.10,0.075,0.94) if state_name=="normal" else (Color(0.05,0.16,0.12,0.95) if state_name in ["hover","focus"] else Color(0.02,0.06,0.04,0.9))
				border = Color(0.78,0.94,0.85,0.50)
				ink = Color("f1f6f3")
				border_w = 1
				radius = 14
			"cycle":
				fill = Color(0.025,0.10,0.075,0.92) if state_name=="normal" else (Color(0.05,0.16,0.12,0.95) if state_name in ["hover","focus"] else Color(0.02,0.06,0.04,0.9))
				border = Color(0.74,0.90,0.80,0.40) if state_name!="disabled" else Color(0.30,0.42,0.36,0.25)
				ink = Color("f1f6f3") if state_name!="disabled" else Color("6a8275")
				border_w = 1
				radius = 8
			"action", "secondary":
				fill = Color(0.025,0.10,0.075,0.94) if state_name=="normal" else (Color(0.04,0.15,0.11,0.96) if state_name in ["hover","focus"] else Color(0.02,0.07,0.05,0.96))
				border = Color(0.74,0.90,0.80,0.45) if state_name!="disabled" else Color(0.25,0.38,0.32,0.3)
				ink = Color("f1f6f3") if state_name!="disabled" else Color("8ba398")
				border_w = 1
				radius = 12
			_:
				fill = Color(0.025,0.10,0.075,0.94) if state_name=="normal" else (Color(0.04,0.14,0.10,0.96) if state_name in ["hover","focus"] else Color(0.02,0.06,0.04,0.9))
				border = Color(0.74,0.90,0.80,0.40) if state_name!="disabled" else Color(0.25,0.38,0.32,0.3)
				ink = Color("f1f6f3") if state_name!="disabled" else Color("8ba398")
				border_w = 1
				radius = 12
				
		var box:StyleBoxFlat = g._box(fill, border)
		box.set_corner_radius_all(radius)
		box.set_border_width_all(border_w)
		node.add_theme_stylebox_override(state_name, box)
		node.add_theme_color_override("font_" + state_name + "_color" if state_name != "normal" else "font_color", ink)
	node.add_theme_constant_override("outline_size", 0)
	node.set_meta("button_role", role)

func tab_button(parent:Node,text:String,action:Callable,selected:bool=false) -> Button:
	var node:=button(parent,text.to_upper(),action);style_button(node,"tab",selected)
	node.add_theme_font_size_override("font_size",14 if compact else 16)
	node.custom_minimum_size.y=maxf(52,44/g.ui_scale)
	return node

func upgrade_button(parent:Node,text:String,action:Callable) -> Button:
	var node:=button(parent,text,action);style_button(node,"upgrade");return node

func meter(parent:Node,title:String,amount:int,total:int) -> void:
	label(parent,title,13 if compact else 14,true)
	var bar:=ProgressBar.new();bar.show_percentage=false;bar.max_value=maxi(1,total);bar.value=amount
	bar.custom_minimum_size.y=6 if compact else 8
	bar.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	bar.add_theme_stylebox_override("background",FlatUiTokens.caixa(FlatUiTokens.CHIP,3))
	bar.add_theme_stylebox_override("fill",FlatUiTokens.caixa(FlatUiTokens.ACTION_MINT,3))
	parent.add_child(bar)

func stat_bar(parent:Node,label_text:String,current_val:float,max_val:float,val_text:String,fill_color:Color=Color("83b99a"),icon_glyph:String="") -> void:
	var row_box:=VBoxContainer.new()
	row_box.add_theme_constant_override("separation",2 if compact else 3)
	row_box.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	parent.add_child(row_box)

	var header_line:=HBoxContainer.new()
	header_line.add_theme_constant_override("separation",4)
	header_line.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	row_box.add_child(header_line)

	var lbl:=Label.new()
	lbl.text=(icon_glyph+" " if not icon_glyph.is_empty() else "")+label_text
	if font_title!=null:lbl.add_theme_font_override("font",font_title)
	elif font_body!=null:lbl.add_theme_font_override("font",font_body)
	lbl.add_theme_font_size_override("font_size",12 if compact else 14)
	lbl.add_theme_color_override("font_color",Color("c7dad1"))
	lbl.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	header_line.add_child(lbl)

	var val_lbl:=Label.new()
	val_lbl.text=val_text
	if font_title!=null:val_lbl.add_theme_font_override("font",font_title)
	val_lbl.add_theme_font_size_override("font_size",12 if compact else 14)
	val_lbl.add_theme_color_override("font_color",Color("f1f6f3"))
	header_line.add_child(val_lbl)

	var bar:=ProgressBar.new()
	bar.show_percentage=false
	bar.custom_minimum_size.y=6 if compact else 8
	bar.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	bar.max_value=maxf(1.0,max_val)
	bar.value=clampf(current_val,0.0,max_val)
	bar.add_theme_stylebox_override("background",FlatUiTokens.caixa(Color(0.03,0.10,0.07,0.85),4))
	bar.add_theme_stylebox_override("fill",FlatUiTokens.caixa(Color("83b99a"),4))
	row_box.add_child(bar)

func card(parent:Node,padding:int=20) -> VBoxContainer:
	var panel:=PanelContainer.new();panel.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	var style:StyleBoxFlat=FlatUiTokens.caixa(Color(0.025,0.085,0.055,0.85),16)
	style.border_color=Color(0.74,0.90,0.80,0.50)
	style.set_border_width_all(1)
	style.set_content_margin_all(0)
	panel.add_theme_stylebox_override("panel",style)
	parent.add_child(panel)
	var margin:=MarginContainer.new()
	for edge in ["left","right","top","bottom"]:margin.add_theme_constant_override("margin_"+edge,padding)
	panel.add_child(margin)
	var box:=VBoxContainer.new();box.add_theme_constant_override("separation",6 if compact else 10);box.set_meta("panel",panel);margin.add_child(box)
	return box

func panel_of(box:VBoxContainer) -> PanelContainer:
	return box.get_meta("panel")

func row(parent:Node,separation:int=12) -> HBoxContainer:
	var box:=HBoxContainer.new();box.add_theme_constant_override("separation",separation);parent.add_child(box);return box

func spacer(parent:Node,vertical:bool=true) -> Control:
	var node:=Control.new();node.mouse_filter=Control.MOUSE_FILTER_IGNORE
	if vertical:node.size_flags_vertical=Control.SIZE_EXPAND_FILL
	else:node.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	parent.add_child(node);return node

func scroll_box(parent:Node) -> VBoxContainer:
	var scroll:=ScrollContainer.new();scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus=true;scroll.scroll_deadzone=12
	scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL;scroll.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	parent.add_child(scroll)
	var box:=VBoxContainer.new();box.size_flags_horizontal=Control.SIZE_EXPAND_FILL;box.add_theme_constant_override("separation",12)
	scroll.add_child(box);return box

func tile(parent:Node,title:String,detail:String,action:Callable,selected:bool=false,min_height:float=84) -> Button:
	var node:=button(parent,"",action,selected);node.custom_minimum_size.y=min_height
	var margin:=MarginContainer.new();margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge in ["left","right","top","bottom"]:margin.add_theme_constant_override("margin_"+edge,14)
	margin.mouse_filter=Control.MOUSE_FILTER_IGNORE;node.add_child(margin)
	var box:=VBoxContainer.new();box.add_theme_constant_override("separation",5);box.mouse_filter=Control.MOUSE_FILTER_IGNORE;margin.add_child(box)
	label(box,title,22);label(box,detail,18,true)
	box.minimum_size_changed.connect(func():node.custom_minimum_size.y=maxf(min_height,box.get_combined_minimum_size().y+28))
	return node

func _item_image_path(kind:String,id:int) -> String:
	match kind:
		"bow":
			return "res://campaign/equipment/bow-%d.png"%id
		"arrow":
			return "res://campaign/equipment/arrow-%d.png"%id
		"costume","skin":
			return "res://campaign/portraits/savi-%d.png"%id
		"character":
			return "res://campaign/portraits/character-%d.png"%id
	return ""

func image_card(parent:Node,title:String,detail:String,image_path:String,action:Callable,selected:bool=false,locked:bool=false,card_size:Vector2=Vector2(120,130),tier_color:Color=Color("355057")) -> Button:
	var node:=Button.new()
	node.custom_minimum_size=card_size
	node.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	var bg_color:=Color(0.10,0.24,0.18,0.96) if selected else Color(0.025,0.085,0.055,0.88)
	var border_color:=Color(0.78,0.94,0.85,0.85) if selected else Color(0.74,0.90,0.80,0.35)
	var box_normal:StyleBoxFlat=g._box(bg_color,border_color)
	box_normal.set_corner_radius_all(12)
	box_normal.set_border_width_all(2 if selected else 1)
	node.add_theme_stylebox_override("normal",box_normal)
	var box_hover:StyleBoxFlat=g._box(bg_color.lightened(0.08),border_color.lightened(0.2))
	box_hover.set_corner_radius_all(12)
	box_hover.set_border_width_all(2)
	node.add_theme_stylebox_override("hover",box_hover)
	var box_pressed:StyleBoxFlat=g._box(bg_color.darkened(0.08),border_color)
	box_pressed.set_corner_radius_all(12)
	box_pressed.set_border_width_all(2)
	node.add_theme_stylebox_override("pressed",box_pressed)
	parent.add_child(node)
	
	var margin:=MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge in ["left","right","top","bottom"]:margin.add_theme_constant_override("margin_"+edge,4 if compact else 6)
	margin.mouse_filter=Control.MOUSE_FILTER_IGNORE
	node.add_child(margin)
	
	var box:=VBoxContainer.new()
	box.add_theme_constant_override("separation",2)
	box.mouse_filter=Control.MOUSE_FILTER_IGNORE
	margin.add_child(box)
	
	var img_holder:=Control.new()
	img_holder.size_flags_vertical=Control.SIZE_EXPAND_FILL
	img_holder.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	img_holder.mouse_filter=Control.MOUSE_FILTER_IGNORE
	box.add_child(img_holder)
	
	var img:=TextureRect.new()
	img.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	img.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	img.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	img.mouse_filter=Control.MOUSE_FILTER_IGNORE
	if ResourceLoader.exists(image_path):
		img.texture=load(image_path)
	if locked:
		img.modulate=Color(0.42,0.46,0.5,0.7)
	img_holder.add_child(img)
	
	if locked:
		var lock_chip:=PanelContainer.new()
		var l_box:StyleBoxFlat=FlatUiTokens.caixa(Color(0.02,0.06,0.04,0.85),6)
		lock_chip.add_theme_stylebox_override("panel",l_box)
		lock_chip.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
		lock_chip.offset_left=-20;lock_chip.offset_top=2;lock_chip.offset_right=-2;lock_chip.offset_bottom=20
		lock_chip.mouse_filter=Control.MOUSE_FILTER_IGNORE
		img_holder.add_child(lock_chip)

		var lock_lbl:=Label.new()
		lock_lbl.text="🔒"
		lock_lbl.add_theme_font_size_override("font_size",10 if compact else 11)
		lock_lbl.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
		lock_lbl.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
		lock_lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		lock_lbl.mouse_filter=Control.MOUSE_FILTER_IGNORE
		lock_chip.add_child(lock_lbl)
	
	var title_lbl:=label(box,title,12 if compact else 14,false,true)
	title_lbl.autowrap_mode=TextServer.AUTOWRAP_OFF
	title_lbl.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
	title_lbl.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.add_theme_color_override("font_color",Color("f1f6f3"))
	
	var sub_lbl:=label(box,detail,10 if compact else 12,true)
	sub_lbl.autowrap_mode=TextServer.AUTOWRAP_OFF
	sub_lbl.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
	sub_lbl.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	if detail.contains("Equipped") or detail.contains("EQUIPPED"):sub_lbl.add_theme_color_override("font_color",Color("a8d5b8"))
	elif detail.contains("coins") or detail.contains("🪙"):sub_lbl.add_theme_color_override("font_color",Color("edd26b"))
	else:sub_lbl.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	sub_lbl.add_theme_color_override("font_color",Color("c7dad1"))
	
	node.set_meta("title_lbl",title_lbl)
	node.set_meta("sub_lbl",sub_lbl)
	node.set_meta("img",img)
	
	if action.is_valid():
		node.pressed.connect(func():
			g.play_sound("res://campaign/audio/click.mp3")
			action.call()
		)
	return node

func coin_capsule(parent:Node) -> PanelContainer:
	var pill:=PanelContainer.new()
	var pill_box:StyleBoxFlat=FlatUiTokens.caixa(Color(0.025,0.085,0.055,0.92),14)
	pill_box.border_color=Color(0.74,0.90,0.80,0.45);pill_box.set_border_width_all(1)
	pill.add_theme_stylebox_override("panel",pill_box)
	pill.size_flags_horizontal=Control.SIZE_SHRINK_END;pill.size_flags_vertical=Control.SIZE_SHRINK_CENTER
	parent.add_child(pill)

	var margin:=MarginContainer.new()
	margin.add_theme_constant_override("margin_left",8 if compact else 10)
	margin.add_theme_constant_override("margin_right",2)
	margin.add_theme_constant_override("margin_top",2);margin.add_theme_constant_override("margin_bottom",2)
	pill.add_child(margin)

	var row_box:=HBoxContainer.new();row_box.add_theme_constant_override("separation",6);margin.add_child(row_box)
	var coin_icon:=TextureRect.new();coin_icon.custom_minimum_size=Vector2(18,18) if compact else Vector2(22,22)
	coin_icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;coin_icon.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if ResourceLoader.exists("res://assets/ui/flat-ui/icons/coin.svg"):
		coin_icon.texture=load("res://assets/ui/flat-ui/icons/coin.svg")
	row_box.add_child(coin_icon)

	var coin:=Label.new();coin.text="%d"%g.profile.data.coins;coin.autowrap_mode=TextServer.AUTOWRAP_OFF
	if font_title!=null:coin.add_theme_font_override("font",font_title)
	coin.add_theme_font_size_override("font_size",14 if compact else 18)
	coin.add_theme_color_override("font_color",Color("f1f6f3"))
	coin.vertical_alignment=VERTICAL_ALIGNMENT_CENTER;row_box.add_child(coin)
	header_coin=coin

	var plus_btn:=Button.new();plus_btn.text="+"
	plus_btn.custom_minimum_size=Vector2.ONE*maxf(52,44/g.ui_scale)
	var p_box:=FlatUiTokens.caixa(Color(0.20,0.39,0.30,0.95),8)
	p_box.border_color=Color(0.78,0.94,0.85,0.70);p_box.set_border_width_all(1)
	plus_btn.add_theme_stylebox_override("normal",p_box)
	var p_hi:=FlatUiTokens.caixa(Color(0.25,0.47,0.36,0.98),8)
	p_hi.border_color=Color(0.78,0.94,0.85,0.85);p_hi.set_border_width_all(1)
	plus_btn.add_theme_stylebox_override("hover",p_hi)
	plus_btn.add_theme_stylebox_override("pressed",p_box)
	plus_btn.add_theme_color_override("font_color",Color("f1f6f3"))
	if font_title!=null:plus_btn.add_theme_font_override("font",font_title)
	plus_btn.add_theme_font_size_override("font_size",14 if compact else 18)
	plus_btn.pressed.connect(func():
		g.play_sound("res://campaign/audio/click.mp3")
		g.show_store()
	)
	row_box.add_child(plus_btn)
	return pill

func header(title:String,back:Callable=Callable()) -> void:
	var box:=card(shell,10 if compact else 14);var line:=row(box)
	if back.is_valid():
		var b:=button(line,"‹ Back",back);b.size_flags_horizontal=Control.SIZE_SHRINK_BEGIN;b.custom_minimum_size=Vector2(116,maxf(56,48/g.ui_scale))
		style_button(b,"cycle")
	var title_box:=VBoxContainer.new();title_box.size_flags_horizontal=Control.SIZE_EXPAND_FILL;line.add_child(title_box)
	label(title_box,title,20 if compact else 26,false,true)
	coin_capsule(line)

func preview(parent:Node) -> Control:
	var area:=Control.new();area.custom_minimum_size=Vector2(100,45 if compact else 80)
	area.size_flags_horizontal=Control.SIZE_EXPAND_FILL;area.size_flags_vertical=Control.SIZE_EXPAND_FILL
	area.mouse_filter=Control.MOUSE_FILTER_STOP;parent.add_child(area)
	var hint:=Label.new();hint.text="Drag to rotate equipment" if g.page=="inventory" and g.inventory_tab in ["bow","arrow"] else "Drag to rotate · Tap to draw";hint.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size",15 if compact else 17);hint.add_theme_constant_override("outline_size",2)
	hint.add_theme_color_override("font_outline_color",Color(0,0,0,0.8));hint.mouse_filter=Control.MOUSE_FILTER_IGNORE
	hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE);hint.offset_top=-28;hint.offset_bottom=0;area.add_child(hint)
	area.gui_input.connect(_preview_input)
	area.resized.connect(func():_fit_preview.call_deferred(area))
	_fit_preview.call_deferred(area)
	return area

func _preview_input(event:InputEvent) -> void:
	if event is InputEventMouseButton and event.device!=-1 and event.button_index==MOUSE_BUTTON_LEFT:
		if event.pressed:preview_drag=true;preview_distance=0
		elif preview_drag:
			preview_drag=false
			if preview_distance<8 and g.hero.visible:g.hero.interact()
	elif event is InputEventMouseMotion and preview_drag:
		_rotate_preview(event.relative.x*0.012);preview_distance+=event.relative.length()
	elif event is InputEventScreenTouch:
		if event.pressed:preview_drag=true;preview_distance=0
		elif preview_drag:
			preview_drag=false
			if not event.canceled and preview_distance<8 and g.hero.visible:g.hero.interact()
	elif event is InputEventScreenDrag and preview_drag:
		_rotate_preview(event.relative.x*0.012);preview_distance+=event.relative.length()

func _rotate_preview(amount:float) -> void:
	if g.page=="inventory" and is_instance_valid(g.gear_preview):g.gear_preview.rotation.y+=amount
	else:g.hero.visuals.rotation.y+=amount

func _fit_preview(area:Control) -> void:
	if not is_instance_valid(area) or not area.is_inside_tree() or g.menu_builder!=self:return
	var viewport_size:Vector2=g.get_viewport().get_visible_rect().size
	var center:Vector2=(area.get_global_rect().position+area.size*0.5*g.ui_scale)
	var fraction:float=clampf(area.size.y*g.ui_scale/viewport_size.y*0.78,0.15,0.85)
	var target:=Vector3(0,6.65,16.5)
	var subject_height:float=g.hero.rig_height+0.26
	if g.page=="inventory" and g.inventory_tab in ["bow","arrow"]:target.y=6.6;subject_height=2.0
	elif g.page=="inventory" and g.inventory_tab=="character":target.y=6.75;subject_height=g.hero.rig_height+0.32
	var distance:=4.2
	var camera:Camera3D=g.menu_camera
	camera.h_offset=0;camera.v_offset=0;camera.fov=38
	camera.position=target+Vector3(0,0.12,distance);camera.look_at(target)
	var baseline:float=camera.project_position(Vector2(viewport_size.x*0.5,0),distance).distance_to(camera.project_position(Vector2(viewport_size.x*0.5,viewport_size.y),distance))
	camera.fov=clampf(rad_to_deg(2*atan(tan(deg_to_rad(38)*0.5)*(subject_height/fraction)/baseline)),28,110)
	var shift:Vector3=camera.project_position(viewport_size*0.5,distance)-camera.project_position(center,distance)
	camera.look_at(target+shift)

# The lobby keeps the original forest palette; other screens have their own styling.
func _lobby_label(parent:Node,text:String,font_size:int=20,muted:bool=false) -> Label:
	var node:=Label.new();node.text=text
	node.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	node.add_theme_font_override("font",ThemeDB.fallback_font)
	node.add_theme_font_size_override("font_size",font_size)
	node.add_theme_color_override("font_color",Color("c7dad1") if muted else Color("f1f6f3"))
	node.mouse_filter=Control.MOUSE_FILTER_IGNORE
	node.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	parent.add_child(node);return node

func _lobby_panel(parent:Node,padding:int=16) -> VBoxContainer:
	var box:=card(parent,padding)
	var style:StyleBoxFlat=g._box(Color(0.025,0.085,0.055,0.82),Color(0.74,0.9,0.8,0.58))
	style.set_corner_radius_all(16);style.set_content_margin_all(0)
	panel_of(box).add_theme_stylebox_override("panel",style)
	box.add_theme_constant_override("separation",6 if compact else 10)
	return box

func _lobby_button(parent:Node,text:String,action:Callable,primary:bool=false) -> Button:
	var node:=button(parent,text,action)
	node.add_theme_font_override("font",ThemeDB.fallback_font)
	node.add_theme_font_size_override("font_size",17 if compact else 20)
	node.custom_minimum_size.y=maxf(56,48/g.ui_scale)
	for state_name in ["normal","hover","pressed","disabled","focus"]:
		var fill:=Color(0.025,0.10,0.075,0.94)
		if primary:fill=Color(0.20,0.39,0.30,0.95)
		if state_name in ["hover","focus"]:fill=fill.lightened(0.12)
		if state_name=="pressed":fill=fill.darkened(0.12)
		var style:StyleBoxFlat=g._box(fill,Color(0.78,0.94,0.85,0.7 if primary else 0.5))
		style.set_corner_radius_all(14)
		node.add_theme_stylebox_override(state_name,style)
		node.add_theme_color_override("font_color" if state_name=="normal" else "font_"+state_name+"_color",Color("f1f6f3") if state_name!="disabled" else Color("8ba398"))
	return node

func _lobby_stat(parent:Node,title:String,value_text:String,value:float,maximum:float) -> void:
	var box:=VBoxContainer.new();box.add_theme_constant_override("separation",3);parent.add_child(box)
	var heading:=row(box,6)
	_lobby_label(heading,title,13 if compact else 15,true)
	var number:=_lobby_label(heading,value_text,14 if compact else 16)
	number.size_flags_horizontal=Control.SIZE_SHRINK_END
	number.autowrap_mode=TextServer.AUTOWRAP_OFF
	var bar:=ProgressBar.new();bar.show_percentage=false;bar.max_value=maxf(maximum,1);bar.value=value
	bar.custom_minimum_size.y=6 if compact else 8
	bar.add_theme_stylebox_override("background",FlatUiTokens.caixa(Color(0.03,0.10,0.07,0.85),4))
	bar.add_theme_stylebox_override("fill",FlatUiTokens.caixa(Color("83b99a"),4))
	box.add_child(bar)

func home() -> void:
	compact=height<650 or g.get_viewport().get_visible_rect().size.y<480
	begin()
	shell.add_theme_constant_override("separation",10 if compact else 14)
	# Match the original broad header and open center, without a tinted hero frame.
	var top:=_lobby_panel(shell,12 if compact else 18)
	panel_of(top).name="LobbyHeader"
	var title_row:=row(top)
	var titles:=VBoxContainer.new();titles.size_flags_horizontal=Control.SIZE_EXPAND_FILL;title_row.add_child(titles)
	_lobby_label(titles,"ARCHER GAME",25 if compact else 30)
	coin_capsule(title_row)

	var middle:=row(shell,14 if compact else 22);middle.size_flags_vertical=Control.SIZE_EXPAND_FILL
	var info:=_lobby_panel(middle,14 if compact else 18)
	var stats_panel:=panel_of(info);stats_panel.name="LobbyCharacterStats"
	stats_panel.custom_minimum_size.x=248 if compact else 278
	stats_panel.size_flags_horizontal=Control.SIZE_FILL;stats_panel.size_flags_vertical=Control.SIZE_SHRINK_CENTER
	_lobby_label(info,"SELECTED ARCHER",14 if compact else 16,true)
	_lobby_label(info,g._character_name(),24 if compact else 28)
	var skin_name:String=g.Catalog.COSTUMES[int(g.profile.data.costume)].name if int(g.profile.data.character)==1 else ""
	_lobby_label(info,(skin_name+" · " if not skin_name.is_empty() else "")+"Level %d / 100"%g.profile.level(),15 if compact else 17,true)
	# These are live combat values, not placeholder percentages.
	var bow:Dictionary=g.Catalog.BOWS[int(g.profile.data.equipped_bow)]
	var arrow:Dictionary=g.Catalog.ARROWS[int(g.profile.data.equipped_arrow)]
	var max_power:float=float(arrow.power)*(1+0.015*(int(arrow.max_level)-1))*float(bow.multiplier)*(1+0.015*(int(bow.max_level)-1))*g.profile.character_power()/(1+0.012*(g.profile.level()-1))*2.188
	_lobby_stat(info,"POWER","%.1f"%g.profile.power(),g.profile.power(),max_power)
	_lobby_stat(info,"ARROW SPEED","%.1f m/s"%g.profile.flight_speed(),g.profile.flight_speed(),float(bow.speed)*38.5)
	_lobby_stat(info,"DRAW TIME","%.2f s"%g.profile.draw_time(),1.0/g.profile.draw_time(),1.0/(.65*float(bow.draw)))
	_lobby_stat(info,"ACCURACY","%.0f%%"%(g.profile.accuracy()*100),g.profile.accuracy()*100,100)
	_lobby_label(info,"%s · Lv. %d\n%s · Lv. %d"%[g.profile.bow_name(),g.profile.data.bow_level,g.profile.arrow_name(),g.profile.data.arrow_level],14 if compact else 16,true)
	var status:=_lobby_label(info,"✓ Equipped",14 if compact else 16,true)
	status.add_theme_color_override("font_color",Color("a8d5b8"))
	var hero_preview:=preview(middle);hero_preview.name="LobbyHeroPreview"
	var can_cycle:bool=g.profile.data.owned_characters.size()>1
	for direction in [-1,1]:
		var step:int=direction
		var cycle_button:=button(hero_preview,"‹" if step<0 else "›",func():g._cycle_character(step))
		cycle_button.name="PreviousCharacter" if step<0 else "NextCharacter"
		cycle_button.disabled=not can_cycle;style_button(cycle_button,"cycle")
		var side:float=maxf(56,48/g.ui_scale)
		cycle_button.set_anchor(SIDE_LEFT,0 if step<0 else 1);cycle_button.set_anchor(SIDE_RIGHT,0 if step<0 else 1)
		cycle_button.set_anchor(SIDE_TOP,.5);cycle_button.set_anchor(SIDE_BOTTOM,.5)
		cycle_button.offset_left=0 if step<0 else -side;cycle_button.offset_right=side if step<0 else 0
		cycle_button.offset_top=-side*.5;cycle_button.offset_bottom=side*.5
		cycle_button.tooltip_text="Previous archer" if step<0 else "Next archer"

	var journey:=_lobby_panel(middle,14 if compact else 18)
	var journey_panel:=panel_of(journey);journey_panel.name="LobbyJourney"
	journey_panel.custom_minimum_size.x=232 if compact else 265
	journey_panel.size_flags_horizontal=Control.SIZE_FILL;journey_panel.size_flags_vertical=Control.SIZE_SHRINK_CENTER
	var definition:Dictionary=g.definitions[g.selected_stage]
	_lobby_label(journey,"CONTINUE YOUR JOURNEY",13 if compact else 15,true)
	_lobby_label(journey,str(definition.chapter),23 if compact else 27)
	_lobby_label(journey,"Stage %d / 5 · %s"%[g.selected_stage%5+1,definition.name],17 if compact else 20,true)
	_lobby_label(journey,g.preparation_hint(definition),13 if compact else 15,true)
	button(journey,"UPGRADE LOADOUT",g.show_collection,true)
	_lobby_label(journey,"Restoration journal · %d / 20"%g.profile.data.chapter_rewards.size(),13 if compact else 15,true)

	var footer:=_lobby_panel(shell,8 if compact else 10);panel_of(footer).name="LobbyNavigation"
	var navigation:=row(footer,6 if compact else 10)
	var names:=["Levels","Store","Collection","Characters","Settings"]
	var actions:Array[Callable]=[g.show_levels,g.show_store,g.show_collection,g.show_characters,g.show_settings]
	for i in range(names.size()):_lobby_button(navigation,names[i],actions[i])
	_lobby_button(navigation,"PLAY  ›",func():g.start_stage(g.selected_stage),true)

func readiness(parent:Node,definition:Dictionary) -> void:
	var total_hp:int=0
	for hp in definition.get("target_hp",[]): total_hp+=int(hp)
	var target_count:int=definition.materials.size()
	label(parent,"Targets: %d · Total HP: %d · Arrows: %d"%[target_count,total_hp,definition.arrows],12 if compact else 14,true)

	var rec_pwr:float=float(definition.get("recommended_power",0))
	var cur_pwr:float=g.profile.power()
	var pwr_ready:bool=cur_pwr>=rec_pwr
	var badge:=label(parent,"✓ POWER: BALANCED (%.0f / %.0f)"%[cur_pwr,rec_pwr] if pwr_ready else "↑ UNDERPOWERED (%.0f / %.0f)"%[cur_pwr,rec_pwr],12 if compact else 14,true)
	badge.add_theme_color_override("font_color",FlatUiTokens.ACTION_MINT if pwr_ready else FlatUiTokens.ORANGE)

	var next_kind:=""
	var needs_store:=false
	for entry in g.readiness_rows(definition):
		var suffix:String="READY" if entry.ready else ("Lv. %d → %d"%[entry.current,entry.required] if entry.tier_ok else str(definition.minimum_gear_tier)+" required")
		var line:=label(parent,("✓  " if entry.ready else "↑  ")+entry.name+"  ·  "+suffix,12 if compact else 14,true)
		line.add_theme_color_override("font_color",FlatUiTokens.ACTION_MINT if entry.ready else FlatUiTokens.ORANGE)
		if not entry.ready and next_kind.is_empty():
			next_kind=entry.kind
			needs_store=not entry.tier_ok

	label(parent,"%d perfect shots + %d spare arrows"%[int(definition.center_hit_budget),maxi(0,definition.arrows-int(definition.center_hit_budget))],12 if compact else 14,true)
	if next_kind.is_empty() and pwr_ready:
		label(parent,"Loadout ready · Center hits deal maximum damage",12 if compact else 14,true)
	else:
		var kind:String=next_kind if not next_kind.is_empty() else "bow"
		if needs_store:
			var find_btn:=button(parent,"Find "+str(definition.minimum_gear_tier)+" gear",func():g.inventory_tab=kind;g.show_store(),true)
			style_button(find_btn,"buy")
		else:
			upgrade_button(parent,"▲ Improve "+kind.capitalize(),func():g.open_upgrade(kind))
	label(parent,"Goal · Archer Lv. %d · Gear Lv. %d"%[int(definition.chapter_character_goal),int(definition.chapter_gear_goal)],11 if compact else 13,true)

func characters() -> void:
	begin();header("Archers",g.show_home)
	g.shop_mode="collection"
	g.inventory_tab="character"
	_build_inventory_ui("character")

func _power_selector(parent:Node,in_game:bool=false) -> void:
	var box:=VBoxContainer.new()
	box.name="PowerUnlockGrid"
	box.add_theme_constant_override("separation",6)
	parent.add_child(box)
	label(box,"POWERS · Mastery Lv. %d"%g.profile.power_level(),12,false,true)
	label(box,"Equipped bow Lv. %d · arrow Lv. %d. Both must reach each unlock."%[g.profile.data.bow_level,g.profile.data.arrow_level],11,true)
	var grid:=GridContainer.new()
	grid.columns=3
	grid.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation",6)
	grid.add_theme_constant_override("v_separation",8)
	box.add_child(grid)
	var buttons:Dictionary={}
	for power in g.Catalog.POWERS:
		var key:String=str(power.key)
		if key=="normal":continue
		var unlocked:bool=g.profile.power_is_unlocked(key)
		var cell:=VBoxContainer.new()
		cell.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		cell.add_theme_constant_override("separation",3)
		grid.add_child(cell)
		var icon_button:=Button.new()
		icon_button.name="Power_"+key
		icon_button.custom_minimum_size=Vector2(64,maxf(56,48/g.ui_scale))
		icon_button.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		icon_button.disabled=not unlocked
		icon_button.tooltip_text="%s · %s"%[power.name,"Select power" if unlocked else g.profile.get_power_lock_reason(key)]
		cell.add_child(icon_button)
		style_button(icon_button,"primary" if unlocked and key==g.selected_power else "standard")
		var icon:=TextureRect.new()
		icon.texture=load("res://campaign/vfx/%s-flight.png"%key)
		icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		icon.offset_left=5;icon.offset_right=-5;icon.offset_top=6;icon.offset_bottom=-6
		icon.mouse_filter=Control.MOUSE_FILTER_IGNORE
		icon.modulate=Color.WHITE if unlocked else Color(.32,.36,.34,.48)
		icon_button.add_child(icon)
		var title:=label(cell,str(power.name),11,true)
		title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
		title.modulate=Color.WHITE if unlocked else Color("82958b")
		var state:=label(cell,"✓ Selected" if unlocked and key==g.selected_power else ("Available" if unlocked else g.profile.get_power_lock_reason(key)),10,true)
		state.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
		state.add_theme_color_override("font_color",Color("a8d5b8") if unlocked else Color("82958b"))
		buttons[key]={"button":icon_button,"state":state}
		icon_button.pressed.connect(func():
			if not g.profile.power_is_unlocked(key):return
			g.select_power(key)
			for id in buttons:
				var active:bool=id==g.selected_power
				style_button(buttons[id].button,"primary" if active else "standard")
				buttons[id].state.text="✓ Selected" if active else ("Available" if g.profile.power_is_unlocked(id) else "Locked · Lv. %d"%int(g.profile.ability_stats(id).level))
		)

static var stage_preview_cache: Dictionary = {}
static func get_stage_preview_texture(id: int) -> Texture2D:
	if stage_preview_cache.has(id):
		return stage_preview_cache[id]
	var path := "res://campaign/stages/previews/stage_%02d.png" % id
	if ResourceLoader.exists(path):
		var tex=load(path) as Texture2D
		if tex!=null:
			stage_preview_cache[id]=tex
			return tex
	if ResourceLoader.exists("res://campaign/stage-preview.png"):
		var tex = load("res://campaign/stage-preview.png")
		stage_preview_cache[id] = tex
		return tex
	return null

func levels() -> void:
	begin()
	g.hero.visible=false

	# Header: Back button on left, LEVELS title in center, currency capsule on right
	var top_line:=row(shell,8 if compact else 12)
	var back_btn:=button(top_line,"‹ Back",g.show_home)
	back_btn.size_flags_horizontal=Control.SIZE_SHRINK_BEGIN
	back_btn.custom_minimum_size=Vector2(116,maxf(56,48/g.ui_scale))
	style_button(back_btn,"cycle")

	var title_panel:=PanelContainer.new()
	var tp_box:=FlatUiTokens.caixa(Color(0.025,0.085,0.055,0.85),14)
	tp_box.border_color=Color(0.74,0.90,0.80,0.50);tp_box.set_border_width_all(1)
	title_panel.add_theme_stylebox_override("panel",tp_box)
	title_panel.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	top_line.add_child(title_panel)

	var tp_margin:=MarginContainer.new()
	tp_margin.add_theme_constant_override("margin_left",16);tp_margin.add_theme_constant_override("margin_right",16)
	tp_margin.add_theme_constant_override("margin_top",4);tp_margin.add_theme_constant_override("margin_bottom",4)
	title_panel.add_child(tp_margin)

	var title_lbl:=label(tp_margin,"LEVELS",18 if compact else 24,false,true)
	title_lbl.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.add_theme_color_override("font_color",Color("f1f6f3"))

	coin_capsule(top_line)

	# Chapter Navigation Strip
	var chapter_strip:=HBoxContainer.new()
	chapter_strip.alignment=BoxContainer.ALIGNMENT_CENTER
	chapter_strip.size_flags_vertical=Control.SIZE_SHRINK_CENTER
	chapter_strip.add_theme_constant_override("separation",6 if compact else 8)
	var chapter_nav:=row(shell,6)
	var previous:=button(chapter_nav,"‹",func():pass)
	previous.name="PreviousChapters"
	previous.size_flags_vertical=Control.SIZE_SHRINK_CENTER
	previous.size_flags_horizontal=Control.SIZE_SHRINK_BEGIN
	previous.custom_minimum_size=Vector2(maxf(44,44/g.ui_scale),maxf(56,48/g.ui_scale))
	var chapter_scroll:=ScrollContainer.new()
	chapter_scroll.name="ChapterScroll"
	chapter_scroll.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	chapter_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_SHOW_NEVER
	chapter_scroll.vertical_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	chapter_scroll.custom_minimum_size.y=maxf(56,48/g.ui_scale)
	chapter_scroll.scroll_deadzone=8
	chapter_nav.add_child(chapter_scroll);chapter_scroll.add_child(chapter_strip)
	var next:=button(chapter_nav,"›",func():pass)
	next.name="NextChapters"
	next.size_flags_vertical=Control.SIZE_SHRINK_CENTER
	next.size_flags_horizontal=Control.SIZE_SHRINK_END
	next.custom_minimum_size=previous.custom_minimum_size
	previous.pressed.connect(func():chapter_scroll.scroll_horizontal-=int(chapter_scroll.size.x*.75))
	next.pressed.connect(func():chapter_scroll.scroll_horizontal+=int(chapter_scroll.size.x*.75))
	var drag:Dictionary={"moved":false}
	chapter_scroll.gui_input.connect(func(event:InputEvent):_chapter_scroll_input(event,chapter_scroll,drag))

	var total_ch:int=int(g.definitions.size()/5)
	for ch_idx in range(total_ch):
		var ch_unlocked:bool=ch_idx*5<=int(g.profile.data.unlocked)
		var ch_btn:=Button.new()
		ch_btn.text="CHAPTER %02d"%(ch_idx+1)
		ch_btn.size_flags_vertical=Control.SIZE_SHRINK_CENTER
		var is_current:bool=(g.selected_chapter==ch_idx)
		var ch_box:=FlatUiTokens.caixa(
			Color(0.20,0.39,0.30,0.95) if is_current else Color(0.025,0.10,0.075,0.94),
			12
		)
		ch_box.border_color=Color(0.78,0.94,0.85,0.70) if is_current else Color(0.74,0.90,0.80,0.35)
		ch_box.set_border_width_all(2 if is_current else 1)
		ch_btn.add_theme_stylebox_override("normal",ch_box)
		ch_btn.add_theme_color_override("font_color",Color("f1f6f3") if is_current else Color("c7dad1"))
		if font_title!=null:ch_btn.add_theme_font_override("font",font_title)
		ch_btn.add_theme_font_size_override("font_size",11 if compact else 13)
		ch_btn.custom_minimum_size=Vector2(115,maxf(52,44/g.ui_scale))
		ch_btn.disabled=not ch_unlocked
		ch_btn.gui_input.connect(func(event:InputEvent):_chapter_scroll_input(event,chapter_scroll,drag))
		ch_btn.pressed.connect(func():
			if bool(drag.moved):return
			g.play_sound("res://campaign/audio/click.mp3")
			g.selected_chapter=ch_idx
			g.selected_stage=mini(ch_idx*5,int(g.profile.data.unlocked))
			g.show_levels()
		)
		chapter_strip.add_child(ch_btn)
		if is_current:chapter_scroll.ensure_control_visible.call_deferred(ch_btn)

	# Horizontal Row of Stage Cards
	var cards_container:=HBoxContainer.new()
	cards_container.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	cards_container.size_flags_vertical=Control.SIZE_EXPAND_FILL
	cards_container.alignment=BoxContainer.ALIGNMENT_CENTER
	cards_container.add_theme_constant_override("separation",8 if compact else 14)
	shell.add_child(cards_container)

	for i in range(5):
		var id:int=g.selected_chapter*5+i
		var stage_id:=id
		var def:Dictionary=g.definitions[id]
		var available:bool=id<=int(g.profile.data.unlocked)
		var is_selected:bool=(g.selected_stage==id)

		var card_btn:=Button.new()
		card_btn.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		card_btn.size_flags_vertical=Control.SIZE_EXPAND_FILL
		card_btn.custom_minimum_size=Vector2(95 if compact else 150,130 if compact else 190)

		var c_style:=FlatUiTokens.caixa(
			Color(0.10,0.24,0.18,0.96) if is_selected else (Color(0.025,0.085,0.055,0.88) if available else Color(0.02,0.06,0.04,0.75)),
			14
		)
		c_style.border_color=Color(0.78,0.94,0.85,0.85) if is_selected else (Color(0.74,0.90,0.80,0.40) if available else Color(0.30,0.42,0.36,0.30))
		c_style.set_border_width_all(2 if is_selected else 1)
		card_btn.add_theme_stylebox_override("normal",c_style)
		var c_hover:=FlatUiTokens.caixa(Color(0.12,0.28,0.22,0.98),14)
		c_hover.border_color=Color(0.78,0.94,0.85,0.90);c_hover.set_border_width_all(2)
		card_btn.add_theme_stylebox_override("hover",c_hover)
		cards_container.add_child(card_btn)

		var c_margin:=MarginContainer.new()
		c_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		c_margin.add_theme_constant_override("margin_left",6);c_margin.add_theme_constant_override("margin_right",6)
		c_margin.add_theme_constant_override("margin_top",6);c_margin.add_theme_constant_override("margin_bottom",6)
		c_margin.mouse_filter=Control.MOUSE_FILTER_IGNORE
		card_btn.add_child(c_margin)

		var c_layout:=VBoxContainer.new()
		c_layout.mouse_filter=Control.MOUSE_FILTER_IGNORE
		c_layout.alignment=BoxContainer.ALIGNMENT_CENTER
		c_margin.add_child(c_layout)

		if available:
			var stage_img:=TextureRect.new()
			stage_img.size_flags_vertical=Control.SIZE_EXPAND_FILL
			stage_img.size_flags_horizontal=Control.SIZE_EXPAND_FILL
			stage_img.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
			stage_img.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_COVERED
			var tex:Texture2D=get_stage_preview_texture(id)
			if tex!=null:
				stage_img.texture=tex
			stage_img.mouse_filter=Control.MOUSE_FILTER_IGNORE
			c_layout.add_child(stage_img)

			var rating:int=int(g.profile.data.stars.get(str(id),0))
			var star_lbl:=label(c_layout,"★".repeat(rating)+"☆".repeat(3-rating),11 if compact else 13,false,true)
			star_lbl.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
			star_lbl.add_theme_color_override("font_color",Color("ffd343"))

			var badge_btn:=Button.new()
			badge_btn.text="LEVEL-%d"%(i+1)
			badge_btn.size_flags_horizontal=Control.SIZE_EXPAND_FILL
			badge_btn.custom_minimum_size.y=24 if compact else 28
			var b_style:=FlatUiTokens.caixa(Color(0.20,0.39,0.30,0.95),8)
			b_style.border_color=Color(0.78,0.94,0.85,0.70);b_style.set_border_width_all(1)
			badge_btn.add_theme_stylebox_override("normal",b_style)
			badge_btn.add_theme_color_override("font_color",Color("f1f6f3"))
			if font_title!=null:badge_btn.add_theme_font_override("font",font_title)
			badge_btn.add_theme_font_size_override("font_size",11 if compact else 13)
			badge_btn.mouse_filter=Control.MOUSE_FILTER_IGNORE
			c_layout.add_child(badge_btn)
		else:
			spacer(c_layout,true)
			var lock_icon:=Label.new()
			lock_icon.text="🔒"
			lock_icon.add_theme_font_size_override("font_size",24 if compact else 36)
			lock_icon.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
			lock_icon.mouse_filter=Control.MOUSE_FILTER_IGNORE
			c_layout.add_child(lock_icon)
			spacer(c_layout,true)

			var lock_badge:=Button.new()
			lock_badge.text="LEVEL-%d"%(i+1)
			lock_badge.size_flags_horizontal=Control.SIZE_EXPAND_FILL
			lock_badge.custom_minimum_size.y=24 if compact else 28
			var lb_style:=FlatUiTokens.caixa(Color(0.02,0.06,0.04,0.85),8)
			lb_style.border_color=Color(0.30,0.42,0.36,0.25);lb_style.set_border_width_all(1)
			lock_badge.add_theme_stylebox_override("normal",lb_style)
			lock_badge.add_theme_color_override("font_color",Color("8ba398"))
			if font_title!=null:lock_badge.add_theme_font_override("font",font_title)
			lock_badge.add_theme_font_size_override("font_size",11 if compact else 13)
			lock_badge.mouse_filter=Control.MOUSE_FILTER_IGNORE
			c_layout.add_child(lock_badge)

		card_btn.pressed.connect(func():
			if available:
				g.play_sound("res://campaign/audio/click.mp3")
				g.selected_stage=stage_id
				g.show_levels()
		)

	# Bottom Controls: Info on left, SELECT button on bottom right (enclosed in _lobby_panel)
	var bottom_panel:=_lobby_panel(shell,8 if compact else 10)
	var bottom_line:=row(bottom_panel,8 if compact else 12)
	var info_box:=VBoxContainer.new()
	info_box.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	bottom_line.add_child(info_box)

	var cur_def:Dictionary=g.definitions[g.selected_stage]
	var cur_title:=label(info_box,"%s · %s"%[cur_def.chapter,cur_def.name],15 if compact else 19,false,true)
	cur_title.add_theme_color_override("font_color",Color("f1f6f3"))
	var sub_info:="%s · %d arrows · %d s"%[str(cur_def.get("encounter_hint","Aim for the center")),cur_def.arrows,cur_def.seconds]
	var sub_lbl:=label(info_box,sub_info,11 if compact else 13,true)
	sub_lbl.add_theme_color_override("font_color",Color("c7dad1"))

	label(info_box,g.preparation_hint(cur_def),12 if compact else 14,true)
	label(info_box,"Chapter goal: both weapons Lv. %d · %s · entry mastery Lv. %d"%[int(cur_def.chapter_gear_goal),g.profile.ability_stats(str(cur_def.get("chapter_power","normal"))).name,int(cur_def.get("minimum_power_level",1))],12 if compact else 14,true)
	button(bottom_line,"UPGRADES",g.show_collection)
	var select_btn:=button(bottom_line,"SELECT",func():g.start_stage(g.selected_stage),true)
	select_btn.size_flags_horizontal=Control.SIZE_SHRINK_END
	select_btn.custom_minimum_size=Vector2(170,maxf(56,48/g.ui_scale))
	style_button(select_btn,"primary")

func inventory() -> void:
	begin()
	var top_box:=card(shell,6 if compact else 8)
	var line:=row(top_box,8 if compact else 12)

	var b:=button(line,"‹ Back",g.show_home)
	b.size_flags_horizontal=Control.SIZE_SHRINK_BEGIN
	b.custom_minimum_size=Vector2(116,maxf(56,48/g.ui_scale))
	style_button(b,"cycle")

	var title_lbl:=label(line,"STORE" if g.shop_mode=="store" else "COLLECTION",16 if compact else 20,false,true)
	title_lbl.size_flags_horizontal=Control.SIZE_SHRINK_BEGIN
	title_lbl.autowrap_mode=TextServer.AUTOWRAP_OFF

	var segment_panel:=PanelContainer.new()
	segment_panel.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	segment_panel.size_flags_vertical=Control.SIZE_SHRINK_CENTER
	var seg_box:=FlatUiTokens.caixa(Color(0.02,0.07,0.05,0.92),12)
	seg_box.border_color=Color(0.74,0.90,0.80,0.35);seg_box.set_border_width_all(1)
	segment_panel.add_theme_stylebox_override("panel",seg_box)
	line.add_child(segment_panel)

	var seg_margin:=MarginContainer.new()
	seg_margin.add_theme_constant_override("margin_left",4);seg_margin.add_theme_constant_override("margin_right",4)
	seg_margin.add_theme_constant_override("margin_top",4);seg_margin.add_theme_constant_override("margin_bottom",4)
	segment_panel.add_child(seg_margin)

	var categories:=HBoxContainer.new()
	categories.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	categories.alignment=BoxContainer.ALIGNMENT_CENTER
	categories.add_theme_constant_override("separation",6)
	seg_margin.add_child(categories)

	var tab_names:=[["BOWS","bow"],["ARROWS","arrow"],["ARCHERS","character"]]
	for pair in tab_names:
		var tab:String=pair[1]
		var is_sel:bool=(g.inventory_tab==tab or (tab=="character" and g.inventory_tab=="costumes"))
		var t_btn:=Button.new()
		t_btn.text=pair[0]
		t_btn.clip_text=false
		t_btn.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		t_btn.custom_minimum_size=Vector2(96 if compact else 114,38 if compact else 44)
		if font_title!=null:t_btn.add_theme_font_override("font",font_title)
		t_btn.add_theme_font_size_override("font_size",13 if compact else 15)
		for st in ["normal","hover","pressed","focus","disabled"]:
			var t_box:StyleBoxFlat
			if is_sel:
				t_box=FlatUiTokens.caixa(Color(0.20,0.39,0.30,0.98),8)
				t_box.border_color=Color(0.78,0.94,0.85,0.80);t_box.set_border_width_all(1)
				t_btn.add_theme_color_override("font_color",Color("f1f6f3"))
			else:
				t_box=FlatUiTokens.caixa(Color(0.0,0.0,0.0,0.0) if st=="normal" else Color(0.05,0.14,0.10,0.6),8)
				t_box.border_color=Color(0.0,0.0,0.0,0.0)
				t_btn.add_theme_color_override("font_color",Color("8ba398") if st=="normal" else Color("d0e5d8"))
			t_btn.add_theme_stylebox_override(st,t_box)
		t_btn.pressed.connect(func():
			g.play_sound("res://campaign/audio/click.mp3")
			g.inventory_tab=tab;g.preview_item=-1;g.preview_character=-1;g.preview_costume=-1;g.show_inventory()
		)
		categories.add_child(t_btn)

	coin_capsule(line)

	var kind:String="character" if g.inventory_tab in ["costumes","character"] else g.inventory_tab
	_build_inventory_ui(kind)

func _build_inventory_ui(kind:String) -> void:
	var entries:Array=g.Catalog.BOWS if kind=="bow" else (g.Catalog.ARROWS if kind=="arrow" else g.Catalog.CHARACTERS)
	var selected:int=-1
	if kind=="character":
		selected=g.preview_character if g.preview_character>=0 else int(g.profile.data.character)
	else:
		selected=g.preview_item if g.preview_item>=0 else int(g.profile.data.equipped_bow if kind=="bow" else g.profile.data.equipped_arrow)

	if g.shop_mode=="collection" and not g.profile.is_owned(kind,selected):
		for i in range(entries.size()):
			if g.profile.is_owned(kind,i):selected=i;break

	if kind=="character":g.preview_character=selected
	else:g.preview_item=selected

	_update_inventory_preview(kind,selected)

	# Top Split: Left 3D Showcase Box & Right SPECIFICATIONS Card (Image 3 Style)
	var top_split:=row(shell,8 if compact else 12)
	top_split.size_flags_vertical=Control.SIZE_EXPAND_FILL

	# Left Area: 3D weapon/character showcase area (completely transparent so the 3D scene and bow are unobstructed)
	var sc_panel:=MarginContainer.new()
	sc_panel.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	sc_panel.size_flags_vertical=Control.SIZE_EXPAND_FILL
	top_split.add_child(sc_panel)

	var sc_layout:=VBoxContainer.new()
	sc_layout.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	sc_layout.size_flags_vertical=Control.SIZE_EXPAND_FILL
	sc_panel.add_child(sc_layout)

	preview(sc_layout)

	var skins_anchor:=VBoxContainer.new()
	skins_anchor.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	sc_layout.add_child(skins_anchor)

	# Right Box: SPECIFICATIONS Panel with lobby panel styling
	var sp_panel:=PanelContainer.new()
	sp_panel.custom_minimum_size.x=230 if compact else 310
	sp_panel.size_flags_horizontal=Control.SIZE_FILL
	sp_panel.size_flags_vertical=Control.SIZE_EXPAND_FILL
	var sp_box:=FlatUiTokens.caixa(Color(0.025,0.085,0.055,0.85),16)
	sp_box.border_color=Color(0.74,0.90,0.80,0.50);sp_box.set_border_width_all(1)
	sp_panel.add_theme_stylebox_override("panel",sp_box)
	top_split.add_child(sp_panel)

	var sp_margin:=MarginContainer.new()
	sp_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	sp_margin.add_theme_constant_override("margin_left",10 if compact else 14)
	sp_margin.add_theme_constant_override("margin_right",10 if compact else 14)
	sp_margin.add_theme_constant_override("margin_top",4 if compact else 10)
	sp_margin.add_theme_constant_override("margin_bottom",4 if compact else 10)
	sp_panel.add_child(sp_margin)

	var sp_layout:=VBoxContainer.new()
	sp_layout.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	sp_layout.size_flags_vertical=Control.SIZE_EXPAND_FILL
	sp_layout.add_theme_constant_override("separation",4 if compact else 6)
	sp_margin.add_child(sp_layout)

	var specs_title:=label(sp_layout,"SPECIFICATIONS",14 if compact else 17,true,true)
	specs_title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	specs_title.add_theme_color_override("font_color",Color("c7dad1"))

	var stats_box:=VBoxContainer.new()
	stats_box.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	stats_box.size_flags_vertical=Control.SIZE_EXPAND_FILL
	stats_box.add_theme_constant_override("separation",3 if compact else 5)
	var stats_scroll:=ScrollContainer.new();stats_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	stats_scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL;sp_layout.add_child(stats_scroll);stats_scroll.add_child(stats_box)

	var cta_box:=VBoxContainer.new()
	cta_box.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	cta_box.add_theme_constant_override("separation",4)
	sp_layout.add_child(cta_box)

	# Fixed-width left rail. Only its contents scroll; preview and actions stay put.
	var shelf_container:=PanelContainer.new()
	shelf_container.name="ItemListPanel"
	shelf_container.custom_minimum_size.x=200 if compact else 220
	shelf_container.size_flags_horizontal=Control.SIZE_FILL
	shelf_container.size_flags_vertical=Control.SIZE_EXPAND_FILL
	var shelf_style:=FlatUiTokens.caixa(Color(0.025,0.085,0.055,0.85),14)
	shelf_style.border_color=Color(0.74,0.90,0.80,0.40);shelf_style.set_border_width_all(1)
	shelf_container.add_theme_stylebox_override("panel",shelf_style)
	top_split.add_child(shelf_container);top_split.move_child(shelf_container,0)
	var rail:=VBoxContainer.new();rail.add_theme_constant_override("separation",8);shelf_container.add_child(rail)
	var rail_title:=label(rail,"ARCHERS" if kind=="character" else ("BOWS" if kind=="bow" else "ARROWS"),18,false,true)
	rail_title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	var shelf_scroll:=ScrollContainer.new()
	shelf_scroll.name="VerticalItemList";shelf_scroll.set_meta("is_items_scroll",true)
	shelf_scroll.vertical_scroll_mode=ScrollContainer.SCROLL_MODE_AUTO
	shelf_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	shelf_scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL
	shelf_scroll.follow_focus=true;shelf_scroll.scroll_deadzone=12
	rail.add_child(shelf_scroll)
	var shelf_strip:=VBoxContainer.new()
	shelf_strip.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	shelf_strip.add_theme_constant_override("separation",10)
	shelf_scroll.add_child(shelf_strip)

	var tiles:Dictionary={}
	for i in range(entries.size()):
		var id:=i;var owned:bool=g.profile.is_owned(kind,id)
		if g.shop_mode=="collection" and not owned:continue
		var detail:=_tile_status_text(kind,id,entries[id],owned)
		var img_path:=_item_image_path(kind,id)
		var is_unl:bool=g.profile.is_unlocked(kind,id)
		var on_item_click:Callable = func():
			_select_inventory_item(kind,id,entries,tiles,stats_box,cta_box,skins_anchor)
		
		var item_tier:String=str(entries[id].get("tier","Basic"))
		var t_color:=Color("455a60")
		if item_tier=="Premium": t_color=Color("3d8c6b")
		elif item_tier=="Epic": t_color=Color("7d4eb8")
		elif item_tier=="Legendary": t_color=Color("b38827")
		elif kind=="character": t_color=Color("3d8c6b") if id==1 else Color("7d4eb8")
		
		var card_w:=174 if compact else 194
		var card_h:=124 if compact else 142
		var item_btn:=image_card(shelf_strip,entries[id].name,detail,img_path,on_item_click,id==selected,not owned and not is_unl,Vector2(card_w,card_h),t_color)
		var detail_lbl:Label=item_btn.get_meta("sub_lbl",null)
		var img_rect:TextureRect=item_btn.get_meta("img",null)
		tiles[id]={"button":item_btn,"label":detail_lbl,"img":img_rect,"tier_color":t_color}

	if g.shop_mode=="collection" and kind=="character":
		var store_card:=button(shelf_strip,"+ Get More Archers",func():
			g.show_store()
		)
		store_card.custom_minimum_size=Vector2(174 if compact else 194, 44)
		style_button(store_card,"action")

	_populate_inventory_stats(stats_box,kind,selected,entries)
	_populate_inventory_cta(cta_box,kind,selected,entries,tiles,stats_box,skins_anchor)
	if kind=="character" and selected==1:
		_render_erin_skins(skins_anchor,stats_box,cta_box,tiles)

func _purchase_status(kind:String,id:int,item:Dictionary) -> String:
	var status:String=g.profile.eligibility_text(kind,id)
	if not status.contains("coins"):status+=" · %d coins"%int(item.price)
	return status

func _update_inventory_preview(kind:String,selected:int) -> void:
	if kind in ["bow","arrow"]:
		if g.preview_character>=0 or g.preview_costume>=0:
			g.preview_character=-1;g.preview_costume=-1;g._spawn_hero()
		g._show_gear()
	else:
		if is_instance_valid(g.gear_preview):
			g.gear_preview.queue_free();g.gear_preview=null
		g.preview_character=selected
		if selected==1:
			if g.preview_costume<0:g.preview_costume=int(g.profile.data.costume)
		else:
			g.preview_costume=-1
		g._spawn_hero()

func _tile_status_text(kind:String,id:int,entry:Dictionary,owned:bool) -> String:
	var is_equipped:bool=false
	if kind=="bow":is_equipped=(int(g.profile.data.equipped_bow)==id)
	elif kind=="arrow":is_equipped=(int(g.profile.data.equipped_arrow)==id)
	elif kind=="character":is_equipped=(int(g.profile.data.character)==id)
	if is_equipped:return "◆ Equipped"
	if g.shop_mode=="collection":
		if kind in ["bow","arrow"]:
			var lv:int=int(g.profile.data[kind+"_levels"][id]) if id<g.profile.data[kind+"_levels"].size() else 1
			return "Owned · Lv. %d"%lv
		elif kind=="character":
			return "Owned · Lv. %d"%g.profile.level_for(id)
		return "Owned · Select"
	if owned:return "✓ Owned"
	if g.profile.is_unlocked(kind,id):
		return "%d coins"%int(entry.price)
	return "🔒 %d coins · Ch. %d"%[int(entry.price), int(entry.get("unlock_chapter",1))]

func _select_inventory_item(kind:String,id:int,entries:Array,tiles:Dictionary,stats_box:VBoxContainer,cta_box:VBoxContainer,skins_anchor:VBoxContainer) -> void:
	if kind=="character":g.preview_character=id
	else:g.preview_item=id
	for item_id in tiles:
		var btn:Button=tiles[item_id].get("button")
		if is_instance_valid(btn):
			var is_sel:bool=(item_id==id)
			var bg_color:=Color(0.10,0.24,0.18,0.96) if is_sel else Color(0.025,0.085,0.055,0.88)
			var border_color:=Color(0.78,0.94,0.85,0.85) if is_sel else Color(0.74,0.90,0.80,0.35)
			var box:StyleBoxFlat=g._box(bg_color,border_color)
			box.set_corner_radius_all(12)
			box.set_border_width_all(2 if is_sel else 1)
			btn.add_theme_stylebox_override("normal",box)
	_update_inventory_preview(kind,id)
	_populate_inventory_stats(stats_box,kind,id,entries)
	_populate_inventory_cta(cta_box,kind,id,entries,tiles,stats_box,skins_anchor)
	if kind=="character" and id==1:
		_render_erin_skins(skins_anchor,stats_box,cta_box,tiles)
	else:
		for c in skins_anchor.get_children():skins_anchor.remove_child(c);c.queue_free()

func _populate_inventory_stats(stats_box:VBoxContainer,kind:String,selected:int,entries:Array) -> void:
	for c in stats_box.get_children():stats_box.remove_child(c);c.queue_free()
	if selected<0 or selected>=entries.size():return
	var item:Dictionary=entries[selected]
	var owned:bool=g.profile.is_owned(kind,selected)
	var is_equipped:bool=false
	if kind=="bow":is_equipped=(int(g.profile.data.equipped_bow)==selected)
	elif kind=="arrow":is_equipped=(int(g.profile.data.equipped_arrow)==selected)
	elif kind=="character":is_equipped=(int(g.profile.data.character)==selected)

	var tier:String=str(item.get("tier",""))
	if not tier.is_empty():
		var tier_color:=Color("c7dad1")
		if tier=="Premium":tier_color=Color("a8d5b8")
		elif tier=="Epic":tier_color=Color("c47aff")
		elif tier=="Legendary":tier_color=Color("ffd343")
		var tier_lbl:=label(stats_box,"["+tier.to_upper()+" EQUIPMENT]",10 if compact else 12,true)
		tier_lbl.add_theme_color_override("font_color",tier_color)
	elif kind=="character":
		var archer_lbl:=label(stats_box,"[STARTER ARCHER]" if selected==1 else "[HERO ARCHER]",10 if compact else 12,true)
		archer_lbl.add_theme_color_override("font_color",Color("a8d5b8") if selected==1 else Color("c47aff"))

	var name_lbl:=label(stats_box,item.name,16 if compact else 20,false,true)
	name_lbl.add_theme_color_override("font_color",Color("f1f6f3"))

	var costume:int=g.preview_costume if kind=="character" and selected==1 and g.preview_costume>=0 else int(g.profile.data.costume)
	var progress:Dictionary=g.profile.upgrade_info(kind,selected,costume)
	label(stats_box,"Level %d / %d"%[progress.level,progress.cap],16,false,true)
	label(stats_box,"Equipped shot damage %.2f"%g.profile.power(),14)
	label(stats_box,"Equipped flight speed %.2f m/s"%g.profile.flight_speed(),14)
	label(stats_box,"Equipped draw time %.3f s"%g.profile.draw_time(),14)
	label(stats_box,str(item.get("trait","Cosmetic appearance")),13,true)
	if int(progress.level)<100:
		var next_text:String={"bow":"Next: +0.22 base damage, +0.12 m/s, faster draw","arrow":"Next: +0.18 base damage, +0.08 m/s","character":"Next: +0.10 base damage, steadier aim, faster draw"}.get(kind,"")
		label(stats_box,next_text,13,true)
	else:label(stats_box,"Mastery complete · Level 100",13,true)
	label(stats_box,"Shared training stays with you when changing items.",12,true)
	label(stats_box,"Quiver supplies are provided by each stage.",12,true)
	if kind in ["bow","arrow"]:_power_selector(stats_box)

func _populate_inventory_cta(cta_box:VBoxContainer,kind:String,selected:int,entries:Array,tiles:Dictionary,stats_box:VBoxContainer,skins_anchor:VBoxContainer) -> void:
	for c in cta_box.get_children():cta_box.remove_child(c);c.queue_free()
	if selected<0 or selected>=entries.size():return
	var item:Dictionary=entries[selected]
	var owned:bool=g.profile.is_owned(kind,selected)
	var is_equipped:bool=false
	if kind=="bow":is_equipped=(int(g.profile.data.equipped_bow)==selected)
	elif kind=="arrow":is_equipped=(int(g.profile.data.equipped_arrow)==selected)
	elif kind=="character":is_equipped=(int(g.profile.data.character)==selected)

	if owned:
		var costume:int=g.preview_costume if kind=="character" and selected==1 and g.preview_costume>=0 else int(g.profile.data.costume)
		if not is_equipped:
			button(cta_box,"EQUIP",func():_do_equip(kind,selected,entries,tiles,stats_box,cta_box,skins_anchor),true)
		_upgrade_action(cta_box,kind,selected,costume,func():
			_refresh_all_tiles(kind,entries,tiles)
			_populate_inventory_stats(stats_box,kind,selected,entries)
			_populate_inventory_cta(cta_box,kind,selected,entries,tiles,stats_box,skins_anchor))
		return

	if g.shop_mode=="store":
		if owned:
			var owned_btn:=button(cta_box,"✓ ALREADY OWNED",func():pass,false)
			style_button(owned_btn,"equipped")
			owned_btn.disabled=true
		else:
			var can_buy_item:bool=g.profile.can_buy(kind,selected)
			var is_unlock:bool=g.profile.is_unlocked(kind,selected)
			var btn_label:String=""
			if is_unlock:
				if can_buy_item:btn_label="Buy · %d coins"%int(item.price)
				else:
					var need:int=int(item.price)-int(g.profile.data.coins)
					btn_label="Buy · %d coins (Need %d more)"%[int(item.price),need]
			else:
				btn_label="🔒 Reach Chapter %d · %d coins"%[int(item.get("unlock_chapter",1)), int(item.price)]
			var buy_btn:=button(cta_box,btn_label,func():
				_do_buy(kind,selected,entries,tiles,stats_box,cta_box,skins_anchor)
			,can_buy_item)
			style_button(buy_btn,"buy" if can_buy_item else "primary")
			buy_btn.disabled=not can_buy_item
	else:
		# COLLECTION MODE
		var btn_row:=VBoxContainer.new();btn_row.add_theme_constant_override("separation",8);cta_box.add_child(btn_row)
		if is_equipped:
			var eq:=button(btn_row,"✓ EQUIPPED",func():pass,false)
			style_button(eq,"equipped")
			eq.disabled=true
		elif owned:
			var equip_btn:=button(btn_row,"SELECT",func():
				_do_equip(kind,selected,entries,tiles,stats_box,cta_box,skins_anchor)
			,true)
			style_button(equip_btn,"primary")

		if owned:
			if kind in ["bow","arrow"]:
				var lv:int=int(g.profile.data[kind+"_levels"][selected]) if selected<g.profile.data[kind+"_levels"].size() else 1
				var max_lv:int=int(item.get("max_level",100))
				if lv<max_lv:
					var cost:int=g.profile.upgrade_cost(kind)
					var can_up:bool=g.profile.can_upgrade(kind)
					var btn_txt:String="▲ UPGRADE · %d 🪙"%cost
					if not can_up:
						if int(g.profile.data.coins)<cost:
							btn_txt="▲ UPGRADE · %d 🪙 (Need %d coins)"%[cost, cost-int(g.profile.data.coins)]
						elif g.profile.upgrade_xp(kind)<g.profile.upgrade_xp_requirement(kind):
							btn_txt="▲ UPGRADE · %d 🪙 (Need %d XP)"%[cost, g.profile.upgrade_xp_requirement(kind)-g.profile.upgrade_xp(kind)]
					var upgrade:=upgrade_button(btn_row,btn_txt,func():
						_do_upgrade(kind,selected,entries,tiles,stats_box,cta_box,skins_anchor)
					)
					upgrade.disabled=not can_up
				else:
					var max_btn:=button(btn_row,"★ MAX LEVEL (Lv. %d)"%lv,func():pass,false)
					style_button(max_btn,"equipped")
					max_btn.disabled=true
					if max_lv<100:
						var next_tier:=button(btn_row,"🛍️ Higher Tier in Store →",func():
							g.play_sound("res://campaign/audio/click.mp3")
							g.shop_mode="store";g.inventory_tab=kind;g.show_inventory()
						,true)
						style_button(next_tier,"action")
			elif kind=="character":
				var char_lv:int=g.profile.level()
				var char_max:int=g.Catalog.CHARACTER_CAP
				if char_lv<char_max:
					var cost:int=g.profile.character_upgrade_cost()
					var can_up:bool=g.profile.can_upgrade_character()
					var btn_txt:String="▲ UPGRADE · %d 🪙"%cost
					if not can_up:
						if int(g.profile.data.coins)<cost:
							btn_txt="▲ UPGRADE · %d 🪙 (Need %d coins)"%[cost, cost-int(g.profile.data.coins)]
						elif g.profile.xp_in_level()<g.profile.xp_requirement():
							btn_txt="▲ UPGRADE · %d 🪙 (Need %d XP)"%[cost, g.profile.xp_requirement()-g.profile.xp_in_level()]
					var upgrade:=upgrade_button(btn_row,btn_txt,func():
						_do_upgrade("character",selected,entries,tiles,stats_box,cta_box,skins_anchor)
					)
					upgrade.disabled=not can_up
				else:
					var max_btn:=button(btn_row,"★ MAX LEVEL (Lv. %d)"%char_lv,func():pass,false)
					style_button(max_btn,"equipped")
					max_btn.disabled=true
		else:
			label(cta_box,"Not Owned",11 if compact else 13,true)
			var can_buy_char:bool=g.profile.can_buy(kind,selected)
			var is_unl_char:bool=g.profile.is_unlocked(kind,selected)
			var btn_text:String=""
			if is_unl_char:
				btn_text="Buy · %d 🪙"%int(item.price) if can_buy_char else "Buy · %d 🪙 (Need more)"%int(item.price)
			else:
				btn_text="Locked · Reach Chapter %d"%int(item.get("unlock_chapter",1))
			var store_buy:=button(btn_row,btn_text,func():
				if can_buy_char:_do_buy(kind,selected,entries,tiles,stats_box,cta_box,skins_anchor)
				else:
					g.shop_mode="store";g.inventory_tab=kind;g.preview_item=selected;g.show_inventory()
			,can_buy_char)
			style_button(store_buy,"buy" if can_buy_char else "primary")
			store_buy.disabled=not can_buy_char

func _render_erin_skins(parent:Node,stats_box:VBoxContainer,cta_box:VBoxContainer,tiles:Dictionary) -> void:
	for c in parent.get_children():parent.remove_child(c);c.queue_free()
	var skin_card:=card(parent,4 if compact else 6)
	var heading:=row(skin_card,4)
	label(heading,"ERIN SKINS · PREVIEW & EQUIP",11 if compact else 13,false,true)

	var carousel:=ScrollContainer.new()
	carousel.vertical_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	carousel.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_AUTO
	carousel.name="ErinSkinCarousel"
	carousel.custom_minimum_size.y=112 if compact else 132
	skin_card.add_child(carousel)

	var strip:=HBoxContainer.new()
	strip.add_theme_constant_override("separation",6 if compact else 8)
	carousel.add_child(strip)

	var cur_costume:int=g.preview_costume if g.preview_costume>=0 else int(g.profile.data.costume)
	if g.shop_mode=="collection" and not g.profile.is_owned("costume",cur_costume):
		cur_costume=int(g.profile.data.costume)
		g.preview_costume=cur_costume
		g._spawn_hero()
	var skin_buttons:Dictionary={}

	for skin_id in [2,1,4,3,5,0]:
		var item:Dictionary=g.Catalog.COSTUMES[skin_id]
		var owned:bool=g.profile.is_owned("costume",skin_id)
		if g.shop_mode=="collection" and not owned:continue
		var is_equipped:bool=(int(g.profile.data.character)==1 and int(g.profile.data.costume)==skin_id)
		var is_sel:bool=(cur_costume==skin_id)
		var is_unl:bool=g.profile.is_unlocked("costume",skin_id)

		var btn:=Button.new()
		btn.custom_minimum_size=Vector2(106,100) if compact else Vector2(120,120)
		var bg_color:=Color(0.10,0.24,0.18,0.96) if is_sel else Color(0.025,0.085,0.055,0.88)
		var border_color:=Color(0.78,0.94,0.85,0.85) if is_sel else (Color(0.50,0.75,0.65,0.50) if owned else Color(0.74,0.90,0.80,0.30))
		var box:StyleBoxFlat=g._box(bg_color,border_color)
		box.set_corner_radius_all(10)
		box.set_border_width_all(2 if is_sel else 1)
		btn.add_theme_stylebox_override("normal",box)
		strip.add_child(btn)

		var m:=MarginContainer.new();m.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		m.add_theme_constant_override("margin_left",3);m.add_theme_constant_override("margin_right",3)
		m.add_theme_constant_override("margin_top",3);m.add_theme_constant_override("margin_bottom",3)
		m.mouse_filter=Control.MOUSE_FILTER_IGNORE;btn.add_child(m)

		var content:=VBoxContainer.new();content.mouse_filter=Control.MOUSE_FILTER_IGNORE;m.add_child(content)
		var img_holder:=Control.new();img_holder.size_flags_vertical=Control.SIZE_EXPAND_FILL;img_holder.mouse_filter=Control.MOUSE_FILTER_IGNORE;content.add_child(img_holder)
		var img:=TextureRect.new()
		img.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		img.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;img.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		img.mouse_filter=Control.MOUSE_FILTER_IGNORE
		var path:="res://campaign/portraits/savi-%d.png"%skin_id
		if ResourceLoader.exists(path):img.texture=load(path)
		if not owned and not is_unl:img.modulate=Color(0.55,0.58,0.62,0.8)
		img_holder.add_child(img)

		if not owned and not is_unl:
			var lock_chip:=PanelContainer.new()
			var l_box:StyleBoxFlat=FlatUiTokens.caixa(Color(0.02,0.06,0.04,0.85),6)
			lock_chip.add_theme_stylebox_override("panel",l_box)
			lock_chip.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
			lock_chip.offset_left=-20;lock_chip.offset_top=2;lock_chip.offset_right=-2;lock_chip.offset_bottom=20
			lock_chip.mouse_filter=Control.MOUSE_FILTER_IGNORE
			img_holder.add_child(lock_chip)
			var lock_lbl:=Label.new()
			lock_lbl.text="🔒"
			lock_lbl.add_theme_font_size_override("font_size",10 if compact else 11)
			lock_lbl.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
			lock_lbl.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
			lock_lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			lock_lbl.mouse_filter=Control.MOUSE_FILTER_IGNORE
			lock_chip.add_child(lock_lbl)

		var skin_name_label:=label(content,item.name,12 if compact else 14,false,true)
		skin_name_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
		var detail_text:=""
		if is_equipped:
			detail_text="◆ Active"
		elif owned:
			detail_text="✓ Owned"
		elif is_unl:
			detail_text="%d coins"%int(item.price)
		else:
			detail_text="🔒 %d coins · Ch.%d"%[int(item.price),int(item.get("unlock_chapter",1))]
		var detail_lbl:=label(content,detail_text,9 if compact else 11,true)
		detail_lbl.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
		if is_equipped:detail_lbl.add_theme_color_override("font_color",Color("85ffe1"))
		elif detail_text.contains("coins"):detail_lbl.add_theme_color_override("font_color",Color("edd26b"))
		else:detail_lbl.add_theme_color_override("font_color",Color("c7dad1"))

		skin_buttons[skin_id]={"button":btn,"detail":detail_lbl,"item":item}
		btn.pressed.connect(func():
			g.play_sound("res://campaign/audio/click.mp3")
			_select_erin_skin(skin_id,stats_box,cta_box,skin_buttons,tiles,parent)
		)

	if g.shop_mode=="collection":
		var store_skin_btn:=Button.new()
		store_skin_btn.text="+ Store"
		store_skin_btn.custom_minimum_size=Vector2(70,100) if compact else Vector2(80,120)
		style_button(store_skin_btn,"action")
		store_skin_btn.pressed.connect(func():
			g.play_sound("res://campaign/audio/click.mp3")
			g.show_store()
		)
		strip.add_child(store_skin_btn)

func _select_erin_skin(skin_id:int,stats_box:VBoxContainer,cta_box:VBoxContainer,skin_buttons:Dictionary,tiles:Dictionary,skins_anchor:VBoxContainer) -> void:
	g.preview_character=1
	g.preview_costume=skin_id
	g._spawn_hero()

	for sid in skin_buttons:
		var btn:Button=skin_buttons[sid].get("button")
		if is_instance_valid(btn):
			var is_sel:bool=(sid==skin_id)
			var owned:bool=g.profile.is_owned("costume",sid)
			var bg_color:=Color(0.10,0.24,0.18,0.96) if is_sel else Color(0.025,0.085,0.055,0.88)
			var border_color:=Color(0.78,0.94,0.85,0.85) if is_sel else (Color(0.50,0.75,0.65,0.50) if owned else Color(0.74,0.90,0.80,0.30))
			var box:StyleBoxFlat=g._box(bg_color,border_color)
			box.set_corner_radius_all(10)
			box.set_border_width_all(2 if is_sel else 1)
			btn.add_theme_stylebox_override("normal",box)

	_populate_skin_stats(stats_box,skin_id)
	_populate_skin_cta(cta_box,skin_id,stats_box,skin_buttons,tiles,skins_anchor)

func _populate_skin_stats(stats_box:VBoxContainer,skin_id:int) -> void:
	for c in stats_box.get_children():stats_box.remove_child(c);c.queue_free()
	var item:Dictionary=g.Catalog.COSTUMES[skin_id]
	var owned:bool=g.profile.is_owned("costume",skin_id)
	var is_equipped:bool=(int(g.profile.data.character)==1 and int(g.profile.data.costume)==skin_id)

	var badge_color:=Color("ffd343") if skin_id==0 else (Color("c47aff") if skin_id in [3,5] else Color("a8d5b8"))
	var badge:=label(stats_box,"[ERIN SPECIAL SKIN]",10 if compact else 12,true)
	badge.add_theme_color_override("font_color",badge_color)

	var sname_lbl:=label(stats_box,item.name,16 if compact else 20,false,true)
	sname_lbl.add_theme_color_override("font_color",Color("f1f6f3"))

	var lv:int=g.profile.level_for(1,skin_id)
	label(stats_box,"Skin Level %d / 100"%lv,16,false,true)
	label(stats_box,"Strength ×%.2f"%(float(item.base_power)*(1+.012*(lv-1))),14)
	label(stats_box,"Each skin trains independently. Upgrades improve damage, draw and stability.",13,true)

func _populate_skin_cta(cta_box:VBoxContainer,skin_id:int,stats_box:VBoxContainer,skin_buttons:Dictionary,tiles:Dictionary,skins_anchor:VBoxContainer) -> void:
	for c in cta_box.get_children():cta_box.remove_child(c);c.queue_free()
	var item:Dictionary=g.Catalog.COSTUMES[skin_id]
	var owned:bool=g.profile.is_owned("costume",skin_id)
	var is_equipped:bool=(int(g.profile.data.character)==1 and int(g.profile.data.costume)==skin_id)

	if owned:
		if not is_equipped:
			button(cta_box,"EQUIP SKIN",func():
				g.profile.equip_character(1);g.profile.equip_costume(skin_id)
				_select_erin_skin(skin_id,stats_box,cta_box,skin_buttons,tiles,skins_anchor),true)
		_upgrade_action(cta_box,"character",1,skin_id,func():_select_erin_skin(skin_id,stats_box,cta_box,skin_buttons,tiles,skins_anchor))
		return

	if g.shop_mode=="store":
		if owned:
			var owned_btn:=button(cta_box,"✓ ALREADY OWNED",func():pass,false)
			style_button(owned_btn,"equipped")
			owned_btn.disabled=true
		else:
			var can_buy_skin:bool=g.profile.can_buy("costume",skin_id)
			var is_unl:bool=g.profile.is_unlocked("costume",skin_id)
			var btn_label:String=""
			if is_unl:
				if can_buy_skin:btn_label="Buy Skin · %d coins"%int(item.price)
				else:
					var need:int=int(item.price)-int(g.profile.data.coins)
					btn_label="Buy Skin · %d coins (Need %d more)"%[int(item.price),need]
			else:
				btn_label="🔒 Reach Chapter %d · %d coins"%[int(item.get("unlock_chapter",1)), int(item.price)]
			var buy_btn:=button(cta_box,btn_label,func():
				if g.profile.buy_costume(skin_id):
					if is_instance_valid(header_coin):header_coin.text="%d"%g.profile.data.coins
					_select_erin_skin(skin_id,stats_box,cta_box,skin_buttons,tiles,skins_anchor)
			,can_buy_skin)
			style_button(buy_btn,"buy" if can_buy_skin else "primary")
			buy_btn.disabled=not can_buy_skin
	else:
		if is_equipped:
			var eq:=button(cta_box,"✓ EQUIPPED",func():pass,false)
			style_button(eq,"equipped")
			eq.disabled=true
		elif owned:
			var equip_btn:=button(cta_box,"SELECT",func():
				g.profile.equip_character(1)
				g.profile.equip_costume(skin_id)
				_select_erin_skin(skin_id,stats_box,cta_box,skin_buttons,tiles,skins_anchor)
			,true)
			style_button(equip_btn,"primary")
		else:
			label(cta_box,"Not Owned",11 if compact else 13,true)

func _do_equip(kind:String,id:int,entries:Array,tiles:Dictionary,stats_box:VBoxContainer,cta_box:VBoxContainer,skins_anchor:VBoxContainer) -> void:
	if kind=="bow":g.profile.equip_bow(id)
	elif kind=="arrow":g.profile.equip_arrow(id)
	elif kind=="character":
		g.profile.equip_character(id)
		if id==1 and g.preview_costume>=0:g.profile.equip_costume(g.preview_costume)
	_refresh_all_tiles(kind,entries,tiles)
	_populate_inventory_stats(stats_box,kind,id,entries)
	_populate_inventory_cta(cta_box,kind,id,entries,tiles,stats_box,skins_anchor)

func _do_buy(kind:String,id:int,entries:Array,tiles:Dictionary,stats_box:VBoxContainer,cta_box:VBoxContainer,skins_anchor:VBoxContainer) -> void:
	var ok:bool=false
	if kind=="character":ok=g.profile.buy_character(id)
	else:ok=g.profile.buy_equipment(kind,id)
	if ok:
		if is_instance_valid(header_coin):header_coin.text="%d"%g.profile.data.coins
		_refresh_all_tiles(kind,entries,tiles)
		_populate_inventory_stats(stats_box,kind,id,entries)
		_populate_inventory_cta(cta_box,kind,id,entries,tiles,stats_box,skins_anchor)

func _do_upgrade(kind:String,id:int,entries:Array,tiles:Dictionary,stats_box:VBoxContainer,cta_box:VBoxContainer,skins_anchor:VBoxContainer) -> void:
	var ok:bool=false
	if kind=="bow":
		if int(g.profile.data.equipped_bow)!=id:
			g.profile.equip_bow(id)
		ok=g.profile.upgrade("bow")
	elif kind=="arrow":
		if int(g.profile.data.equipped_arrow)!=id:
			g.profile.equip_arrow(id)
		ok=g.profile.upgrade("arrow")
	elif kind=="character":
		if int(g.profile.data.character)!=id:
			g.profile.equip_character(id)
		ok=g.profile.upgrade_character()
	if ok:
		g.play_sound("res://campaign/audio/click.mp3")
		if is_instance_valid(header_coin):header_coin.text="%d"%g.profile.data.coins
		_refresh_all_tiles(kind,entries,tiles)
		_populate_inventory_stats(stats_box,kind,id,entries)
		_populate_inventory_cta(cta_box,kind,id,entries,tiles,stats_box,skins_anchor)

func _refresh_all_tiles(kind:String,entries:Array,tiles:Dictionary) -> void:
	for id in tiles:
		var owned:bool=g.profile.is_owned(kind,id)
		var is_unl:bool=g.profile.is_unlocked(kind,id)
		var detail_lbl:Label=tiles[id].get("label")
		if is_instance_valid(detail_lbl):
			var new_text:=_tile_status_text(kind,id,entries[id],owned)
			detail_lbl.text=new_text
			if new_text.contains("Equipped"):detail_lbl.add_theme_color_override("font_color",Color("85ffe1"))
			elif new_text.contains("coins"):detail_lbl.add_theme_color_override("font_color",Color("edd26b"))
			else:detail_lbl.add_theme_color_override("font_color",Color("c7dad1"))
		var img:TextureRect=tiles[id].get("img")
		if is_instance_valid(img):
			img.modulate=Color.WHITE if owned or is_unl else Color(.8,.85,.87,1)

func settings() -> void:
	begin();header("Settings",g.show_pause if g.state=="paused" else g.show_home)
	if g.state=="menu":g.hero.visible=false
	var panel:=card(shell,18);panel_of(panel).size_flags_vertical=Control.SIZE_EXPAND_FILL
	var body:=scroll_box(panel)
	var sound_title:=label(body,"SOUND",16 if compact else 19,true,true)
	sound_title.add_theme_color_override("font_color",Color("a8d5b8"))
	setting_toggle(body,"Background music","bg_sound")
	setting_toggle(body,"Game sounds","game_sound")
	setting_slider(body,"Music volume","bg_volume",0,1,0.05)
	setting_slider(body,"Game volume","game_volume",0,1,0.05)
	var ctrl_title:=label(body,"CONTROLS",16 if compact else 19,true,true)
	ctrl_title.add_theme_color_override("font_color",Color("a8d5b8"))
	setting_slider(body,"Look sensitivity","sensitivity",0.3,2,0.1)
	if OS.has_feature("mobile"):label(body,"Touch controller enabled · Landscape only",16,true)
	else:setting_toggle(body,"Preview touch controller","touch_controls",true)
	setting_toggle(body,"Aim trajectory assistance","assist")
	if not OS.has_feature("mobile"):setting_toggle(body,"Fullscreen","fullscreen")
	setting_toggle(body,"Reduced motion","reduced_motion")
	label(body,"Keyboard: Space jump · Q dodge · Hold F/R for power · Mouse: left shoot, right aim. Gamepad: A jump · B dodge · X/Y hold power · RT shoot · LT aim.",15,true).autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	label(body,"Touch: left stick moves · Drag to look · Tap SHOOT for an instant arrow. Hold POWER, then release to fire. AIM + hold SHOOT also charges. JUMP vaults low attacks; DODGE cancels aim.",15,true).autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	label(body,"Arrowglade · "+str(ProjectSettings.get_setting("application/config/version","development"))+" · Combat revision 4",14,true)
	if g.Catalog.TEST_UNLOCK_CHARACTERS:label(body,"Character test access is enabled for this build.",15,true)

func _style_toggle(toggle:Button) -> void:
	var on:bool=toggle.button_pressed
	var fill:=Color(0.20,0.39,0.30,0.95) if on else Color(0.025,0.10,0.075,0.94)
	var border:=Color(0.78,0.94,0.85,0.70) if on else Color(0.74,0.90,0.80,0.40)
	var ink:=Color("f1f6f3") if on else Color("8ba398")
	var box:StyleBoxFlat=g._box(fill,border)
	box.set_corner_radius_all(12)
	box.set_border_width_all(2 if on else 1)
	toggle.add_theme_stylebox_override("normal",box)
	toggle.add_theme_stylebox_override("hover",box)
	toggle.add_theme_stylebox_override("pressed",box)
	toggle.add_theme_stylebox_override("focus",box)
	toggle.add_theme_color_override("font_color",ink)
	toggle.add_theme_color_override("font_pressed_color",ink)
	toggle.add_theme_color_override("font_hover_color",ink)

func setting_toggle(parent:Node,title:String,key:String,rebuild:bool=false) -> void:
	var box:=row(parent);var text:=label(box,title,18 if compact else 21);text.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	text.add_theme_color_override("font_color",Color("f1f6f3"))
	var toggle:=Button.new();toggle.toggle_mode=true;toggle.button_pressed=bool(g.profile.data.settings.get(key,false))
	toggle.text="ON" if toggle.button_pressed else "OFF";toggle.custom_minimum_size=Vector2(70,36) if compact else Vector2(85,42)
	_style_toggle(toggle)
	box.add_child(toggle)
	toggle.toggled.connect(func(value:bool):
		toggle.text="ON" if value else "OFF"
		_style_toggle(toggle)
		g.play_sound("res://campaign/audio/click.mp3")
		g.profile.data.settings[key]=value
		g._apply_settings()
		g.profile.save_profile()
		if rebuild:g._refresh_layout.call_deferred()
	)

func setting_slider(parent:Node,title:String,key:String,minimum:float,maximum:float,step:float) -> void:
	var box:=VBoxContainer.new();box.add_theme_constant_override("separation",4);parent.add_child(box)
	var title_lbl:=label(box,title,16 if compact else 19)
	title_lbl.add_theme_color_override("font_color",Color("f1f6f3"))
	var slider:=HSlider.new();slider.custom_minimum_size.y=36 if compact else 42
	slider.min_value=minimum;slider.max_value=maximum;slider.step=step;slider.value=float(g.profile.data.settings.get(key,0.7))
	box.add_child(slider)
	slider.value_changed.connect(func(value:float):
		g.profile.data.settings[key]=value
		g._apply_settings()
		g.profile.save_profile()
	)

func _retry_level() -> void:
	if not g.practice:g.profile.fail_run()
	g.start_stage(g.selected_stage if g.practice else g.selected_stage,g.practice)

func pause() -> void:
	begin();spacer(shell)
	var center:=CenterContainer.new();shell.add_child(center)
	var box:=card(center,16 if compact else 24);panel_of(box).custom_minimum_size.x=minf(width-g.safe_margins.x-g.safe_margins.z,500)
	label(box,"Paused",30)
	label(box,"Stage %d / 5 · Checkpoint saved"%[g.selected_stage%5+1] if not g.practice else "Practice · No coin rewards",18,true)
	button(box,"Resume",g.resume_game,true);button(box,"Settings",g.show_settings)
	button(box,"Retry practice" if g.practice else "Retry stage",_retry_level);button(box,"Home",g.show_home)
	spacer(shell)

func results() -> void:
	begin();header("Results")
	var panel:=card(shell,16 if compact else 20);panel_of(panel).size_flags_vertical=Control.SIZE_EXPAND_FILL
	var box:=scroll_box(panel);var result:Dictionary=g.last_result
	label(box,result.get("reason","Challenge complete"),30)
	var stars:int=int(result.get("stars",0));label(box,"★".repeat(stars)+"☆".repeat(3-stars),38)
	label(box,"Accuracy  %d%% · Time left  %.1f s\nArrows used  %d · Targets cleared  %d / %d"%[roundi(float(result.get("accuracy",0))*100),g.time_left,g.shots,g.completed,g.current_definition.materials.size()],22)
	var reward:Dictionary=result.get("reward",{"xp":0,"coins":0,"saved":true})
	label(box,"Practice · No rewards" if g.practice else "+%d training XP · +%d coins%s"%[reward.xp,reward.coins,"" if reward.saved else " · Save failed"],21,true)
	var success:bool=bool(result.get("success",false))
	if not g.practice:
		label(box,"Stage %d / 5 · Continue this level"%[g.selected_stage%5+1] if success and g.selected_stage%5!=4 else ("🌿 Level Completed · %s Restored!"%g.current_definition.chapter if success else "Stage failed. Your checkpoint is saved. Retry as often as you like."),20,true)
	var earned_badges:Array=result.get("performance",{}).get("badges",[])
	if not earned_badges.is_empty():label(box,"Mastery: "+" · ".join(earned_badges),18,true)
	if success and bool(reward.get("chapter_complete",false)):label(box,"Restoration journal entry unlocked",18,true)
	if success and g.selected_stage==99:label(box,"The Hollow Crown is free. The guardian bows, and Luma carries its restored light home. Arrowglade lives again.",18,true)
	var footer:=row(shell,14);button(footer,"Home",g.show_home);button(footer,"Retry practice" if g.practice else "Retry stage",_retry_level,true)
	if success and g.selected_stage<g.definitions.size()-1 and not g.practice:button(footer,"Next level  ›" if g.selected_stage%5==4 else "Next stage  ›",func():g.start_stage(g.selected_stage+1),true)

func hud() -> void:
	begin()
	var focus:=ColorRect.new();focus.mouse_filter=Control.MOUSE_FILTER_IGNORE
	focus.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	g.focus_material=ShaderMaterial.new();g.focus_material.shader=load("res://campaign/focus.gdshader");focus.material=g.focus_material
	g.ui.add_child(focus);g.ui.move_child(focus,0)
	var top:HBoxContainer=row(shell,8)
	var objective:=card(top,8);g.hud_objective=label(objective,"%s · Stage %d / 5\n%s"%[g.current_definition.chapter,g.selected_stage%5+1,g.current_definition.name],13 if compact else 15)
	var clock:=card(top,8);panel_of(clock).size_flags_horizontal=Control.SIZE_SHRINK_BEGIN;panel_of(clock).custom_minimum_size.x=92
	g.hud_timer=label(clock,"00:00",16 if g.practice else 18);g.hud_timer.autowrap_mode=TextServer.AUTOWRAP_OFF;g.hud_timer.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	var coins:=card(top,8);panel_of(coins).size_flags_horizontal=Control.SIZE_SHRINK_END;var coin_text:=label(coins,"%d coins"%g.profile.data.coins,14);coin_text.autowrap_mode=TextServer.AUTOWRAP_OFF
	var pause_button:=button(top,"Ⅱ",g.show_pause);pause_button.custom_minimum_size=Vector2(46,36);pause_button.size_flags_horizontal=Control.SIZE_SHRINK_END
	var center:=Control.new();center.size_flags_vertical=Control.SIZE_EXPAND_FILL;center.mouse_filter=Control.MOUSE_FILTER_IGNORE;shell.add_child(center)
	var footer:=row(shell,8)
	var help:=card(footer,10);var instructions:=label(help,"Move · Tap SHOOT · AIM + hold for charge" if g.touch_enabled() else "Click: quick shot · Right mouse + hold left: charge · Q: dodge",17,true);instructions.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	var ammo:=card(footer,10);panel_of(ammo).size_flags_horizontal=Control.SIZE_SHRINK_END;panel_of(ammo).custom_minimum_size.x=200;g.hud_ammo=label(ammo,"",19)
	if g.is_combat():
		panel_of(help).visible=false;panel_of(ammo).visible=false
		var combat_hud=preload("res://campaign/combat_hud.gd").new();combat_hud.game=g;g.combat_hud=combat_hud;g.ui.add_child(combat_hud)
	if not g.touch_enabled() and ((g.selected_power != "normal") or g.profile.power_level() >= 20 or g.practice):
		var power:=card(footer,6);power.add_theme_constant_override("separation",2)
		panel_of(power).size_flags_horizontal=Control.SIZE_SHRINK_END;panel_of(power).custom_minimum_size.x=220
		var info:Dictionary=g.profile.ability_stats(g.selected_power)
		var power_title:=label(power,"%s · %d"%[info.name,int(info.get("focus",0))],14,false,true)
		power_title.add_theme_color_override("font_color",Color("f1f6f3"))
		var cd_init:float=float(info.get("cooldown",0.0))
		var sub_label:=label(power,("Focus · %.1f s"%cd_init) if cd_init>0 else "Focus",12,true)
		sub_label.add_theme_color_override("font_color",Color("83b99a"))
		var meter:=ProgressBar.new();meter.show_percentage=false;meter.max_value=100;meter.custom_minimum_size.y=5
		var m_fill:=FlatUiTokens.caixa(Color("83b99a"),2);meter.add_theme_stylebox_override("fill",m_fill)
		var m_bg:=FlatUiTokens.caixa(Color("1b2a24"),2);meter.add_theme_stylebox_override("background",m_bg)
		meter.value=g.focus_meter;power.add_child(meter)
		var pwr_btn:=button(power,"HOLD POWER · F",func():pass,true)
		pwr_btn.focus_mode=Control.FOCUS_NONE
		pwr_btn.button_down.connect(func():g.begin_power_charge(g.profile.selected_power(),"ui:primary"))
		pwr_btn.button_up.connect(func():g.end_power_charge("ui:primary"))
		pwr_btn.custom_minimum_size.y=48;style_button(pwr_btn,"primary")
		var timer:=Timer.new();timer.wait_time=0.05;timer.process_mode=Node.PROCESS_MODE_ALWAYS;g.ui.add_child(timer)
		timer.timeout.connect(func():
			if not is_instance_valid(g) or not is_instance_valid(power_title):return
			var cur_info:Dictionary=g.profile.ability_stats(g.selected_power)
			power_title.text="%s · %d"%[cur_info.name,int(cur_info.get("focus",0))]
			meter.value=g.focus_meter
			var reason:String=g.power_block_reason(g.selected_power)
			sub_label.text=reason
			pwr_btn.text=("READY · RELEASE" if g.draw_amount>=.95 else "CHARGING · %d%%"%roundi(g.draw_amount*100)) if g.hero.drawing and g.power_armed else ("ARMED · HOLD F" if g.power_armed else "HOLD POWER · F")
			style_button(pwr_btn,"equipped" if g.power_armed else ("primary" if reason=="Ready" else "standard"))
		)
		timer.start()
		var secondary:String=g.profile.secondary_power()
		if secondary!="normal":
			var secondary_btn:=button(power,"Hold %s · R"%g.profile.ability_stats(secondary).name,func():pass)
			secondary_btn.focus_mode=Control.FOCUS_NONE
			secondary_btn.button_down.connect(func():g.begin_power_charge(secondary,"ui:secondary"))
			secondary_btn.button_up.connect(func():g.end_power_charge("ui:secondary"))
	var message_y:float=210.0/maxf(1,g.ui.size.y) if g.is_combat() else (0.31 if not compact else 0.37)
	g.hud_message=_overlay_label("",16 if g.is_combat() else 20,message_y,0.62,50 if g.is_combat() else 70)
	g.hud_ready=_ready_banner()
	g.hud_cross=_overlay_label("+",20,0.5,0.07,32);g.hud_cross.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	g.hud_draw=ProgressBar.new();g.hud_draw.show_percentage=false;g.hud_draw.max_value=1
	g.hud_draw.set_anchors_and_offsets_preset(Control.PRESET_CENTER);g.hud_draw.offset_left=-44;g.hud_draw.offset_right=44;g.hud_draw.offset_top=35;g.hud_draw.offset_bottom=41;g.ui.add_child(g.hud_draw)
	g.hud_draw.visible=not g.is_combat()

func _ready_banner() -> Label:
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.set_anchor(SIDE_LEFT, 0.20); panel.set_anchor(SIDE_RIGHT, 0.80)
	panel.set_anchor(SIDE_TOP, 0.15); panel.set_anchor(SIDE_BOTTOM, 0.15)
	panel.offset_left = 0; panel.offset_right = 0
	panel.offset_top = -42; panel.offset_bottom = 42
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.02, 0.05, 0.04, 0.85)
	style.border_color = Color(0.35, 0.58, 0.44, 0.45)
	style.set_border_width_all(1)
	style.set_corner_radius_all(10)
	style.content_margin_left = 18; style.content_margin_right = 18
	style.content_margin_top = 8; style.content_margin_bottom = 8
	panel.add_theme_stylebox_override("panel", style)
	g.ui.add_child(panel)
	var lbl := label(panel, "", 13 if compact else 14)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.visible = false
	return lbl

func _overlay_label(text:String,font_size:int,y_ratio:float,width_ratio:float,min_height:float) -> Label:
	var node:=label(g.ui,text,font_size);node.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	node.set_anchor(SIDE_LEFT,(1-width_ratio)*0.5);node.set_anchor(SIDE_RIGHT,(1+width_ratio)*0.5)
	node.set_anchor(SIDE_TOP,y_ratio);node.set_anchor(SIDE_BOTTOM,y_ratio)
	node.offset_left=0;node.offset_right=0
	node.offset_top=-min_height*0.5;node.offset_bottom=min_height*0.5
	return node

func _upgrade_action(parent:VBoxContainer,kind:String,id:int,costume:int,refresh:Callable) -> void:
	var info:Dictionary=g.profile.upgrade_info(kind,id,costume)
	if int(info.level)>=int(info.cap):
		label(parent,"MAX FOR THIS TIER · Lv. %d / %d"%[info.level,info.cap],14,true)
		if int(info.cap)<100:
			var entries:Array=g.Catalog.BOWS if kind=="bow" else g.Catalog.ARROWS
			var next_id:int=id
			for index in range(entries.size()):
				if int(entries[index].tier_index)==int(entries[id].tier_index)+1:next_id=index;break
			label(parent,"Continue with %s · starts at Lv. %d, cap %d."%[entries[next_id].name,g.Catalog.tier_start(int(entries[next_id].tier_index)),entries[next_id].max_level],12,true)
			var next_owned:bool=g.profile.is_owned(kind,next_id)
			button(parent,("Equip owned " if next_owned else "Next tier · ")+str(entries[next_id].name),func():
				g.shop_mode="collection" if next_owned else "store";g.inventory_tab=kind;g.preview_item=next_id;g.show_inventory(),true)
		return
	var text:String="UPGRADE · Lv. %d · %d coins"%[int(info.level)+1,info.cost]
	var action:Button=upgrade_button(parent,text,func():
		if g.profile.upgrade_item(kind,id,costume):
			if is_instance_valid(header_coin):header_coin.text=str(g.profile.data.coins)
			refresh.call())
	action.disabled=not bool(info.ready)
	if not info.ready:label(parent,"Need %d more coins. Replay a cleared stage to earn coins."%maxi(0,int(info.cost)-int(g.profile.data.coins)),12,true)

func _chapter_scroll_input(event:InputEvent,scroller:ScrollContainer,drag:Dictionary) -> void:
	if event is InputEventMouseButton:
		if event.button_index==MOUSE_BUTTON_LEFT and event.pressed:drag.moved=false
		if event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
			scroller.scroll_horizontal+=-160 if event.button_index==MOUSE_BUTTON_WHEEL_UP else 160
	if event is InputEventScreenTouch and event.pressed:drag.moved=false
	if event is InputEventScreenDrag:
		if absf(event.relative.x)>2:drag.moved=true
		scroller.scroll_horizontal-=int(event.relative.x)
	if event is InputEventMouseMotion and event.button_mask&MOUSE_BUTTON_MASK_LEFT:
		if absf(event.relative.x)>2:drag.moved=true
		scroller.scroll_horizontal-=int(event.relative.x)
