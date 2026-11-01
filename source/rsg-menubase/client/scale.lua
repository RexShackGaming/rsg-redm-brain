function MenuData.SetScale(scale)
	SendNUIMessage({
		ak_menubase_action = "setScale",
		scale = scale
	})
end

exports("SetScale", function(scale)
	MenuData.SetScale(scale)
end)