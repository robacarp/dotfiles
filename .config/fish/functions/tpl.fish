function tpl
  terraform plan -out=.plan.out $argv | landscape
end
