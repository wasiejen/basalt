# 2026-11-25_16-32 force push a branch onto another
git -C D:/AI/runtimes/basalt-squash push --force-with-lease origin feat/slot-pin-rebased-v3:feat/slot-pin-integrated

# 2026-11-23_17-15 update my_build based on another branch

git -C D:\AI\runtimes\basalt_clone status --short            (if dirty: commit or stash first)
git -C D:\AI\runtimes\basalt_clone branch my_build-legacy
git -C D:\AI\runtimes\basalt_clone checkout my_build
if merge is needed to resolve:
git -C D:\AI\runtimes\basalt_clone push --force-with-lease origin my_build
finish with hard reset to the desired branc
git -C D:\AI\runtimes\basalt_clone reset --hard <branch>


# 2026-11-23_16-14 how to create this repo
PS D:\AI\runtimes> git init D:\AI\runtimes\basalt-scripts
PS D:\AI\runtimes> git -C D:\AI\runtimes\basalt-scripts remote add origin https://github.com/wasiejen/basalt

# 2026-11-22 how to run greedy compare manually
// get the hash from base
git merge-base main feat/session-slot-pin
// check out hash in a new folder parallel to the basalt_clone (sibling folder)
git worktree add ../basalt-base 97e2e7110578aeb7f8708dab176b910589b35047

copy in the build.bat and adapt the ROOT or start with shell and new absolut root as first argument

:: 0) control: proves YOUR box reproduces greedy at all
python basalt_base\tools\greedy_identity.py basalt_base\bin\basalt.exe basalt_base\bin\basalt.exe --model D:\AI\models\basalt\Qwen3.8-FN-UD-IQ3_XXS.basalt -- --expert-cache 4000 --vram-reserve-mib 1024 --gpu 1

:: 1) the PR check: base build vs branch build (flag untouched = off)
python basalt_base\tools\greedy_identity.py basalt_base\bin\basalt.exe basalt_clone\bin\basalt.exe --model D:\AI\models\basalt\Qwen3.8-FN-UD-IQ3_XXS.basalt -- --expert-cache 4000 --vram-reserve-mib 1024 --gpu 1


PS D:\AI\runtimes> python basalt_base\tools\greedy_identity.py basalt_base\bin\basalt.exe basalt_base\bin\basalt.exe --model D:\AI\models\basalt\Qwen3.8-FN-UD-IQ3_XXS.basalt -- --expert-cache 4000 --vram-reserve-mib 1024 --gpu 1
ref: 900 tokens, 3 requests
new: 900 tokens, 3 requests
GREEDY IDENTICAL

PS D:\AI\runtimes> python basalt_base\tools\greedy_identity.py basalt_base\bin\basalt.exe basalt_clone\bin\basalt.exe --model D:\AI\models\basalt\Qwen3.8-FN-UD-IQ3_XXS.basalt -- --expert-cache 4000 --vram-reserve-mib 1024 --gpu 1
ref: 900 tokens, 3 requests
new: 900 tokens, 3 requests
GREEDY IDENTICAL


python basalt_main\tools\greedy_identity.py basalt_main\bin\basalt.exe basalt_clone\bin\basalt.exe --model D:\AI\models\basalt\Qwen3.8-FN-UD-IQ3_XXS.basalt -- --expert-cache 4000 --vram-reserve-mib 1024 --gpu 1
