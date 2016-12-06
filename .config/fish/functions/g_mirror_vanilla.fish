function g_mirror_vanilla
	echo mirroring _vanilla into _development...
  psql -c "DROP DATABASE polymer_development"
  psql -c "CREATE DATABASE polymer_development WITH TEMPLATE polymer_vanilla OWNER polymer";
end
