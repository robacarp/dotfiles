function battery --description 'print approximate battery level as a percentage'
	ioreg -l | grep -i legacybattery | tr -s '",={|' ' ' | awk '{printf("%.0f%%", $9/$7*100)}'
end
