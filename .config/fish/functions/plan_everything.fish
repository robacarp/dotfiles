function plan_everything --description "Runs terraform plan in every .terraform workspace below PWD; uses a tmux window per workspace only if more than one is found"
    set -l root (pwd)
    set -l dirs
    for tf_dir in (find $root -type d -name .terraform -prune | sort)
        set -a dirs (path resolve (dirname $tf_dir))
    end

    if test (count $dirs) -eq 0
        echo "plan_everything: no .terraform directories found below $root" >&2
        return 1
    end

    if test (count $dirs) -eq 1
        set -l dir $dirs[1]
        set -l cmd_parts terraform -chdir=$dir plan
        # Mirrors .github/workflows/git_ops.yml: most projects auto-load
        # terraform.tfvars, but amp/ecs needs its production.tfvars passed explicitly.
        if test -e $dir/production.tfvars
            set -a cmd_parts -var-file=production.tfvars
        end
        set -a cmd_parts -out=.plan.out
        $cmd_parts
        return
    end

    if not command -q tmux
        echo "plan_everything: tmux is not installed" >&2
        return 1
    end

    set -l already_in_tmux (test -n "$TMUX"; and echo 1)
    set -l session
    if test -n "$already_in_tmux"
        set session (tmux display-message -p '#S')
    else
        set session plan_everything_(date +%s)
    end

    for i in (seq (count $dirs))
        set -l dir $dirs[$i]
        set -l label
        if test "$dir" = "$root"
            set label (path basename $dir)
        else
            set label (string replace -- "$root/" '' $dir)
        end

        set -l cmd_parts terraform plan
        if test -e $dir/production.tfvars
            set -a cmd_parts -var-file=production.tfvars
        end
        set -a cmd_parts -out=.plan.out

        if test $i -eq 1; and not test -n "$already_in_tmux"
            tmux new-session -d -s $session -n $label -c $dir
        else
            tmux new-window -t $session -n $label -c $dir
        end
        tmux send-keys -t $session:$label (string join -- ' ' $cmd_parts) Enter
    end

    if not test -n "$already_in_tmux"
        tmux attach-session -t $session
    end
end
