# Generates device/patches/0001-wait-introduce-waitid-P_PIDFD.patch for the lineage-20 4.19 kernel:
# backport of upstream 5.4 "wait: add waitid(P_PIDFD) support" + "pid: add pidfd_get_pid()".
# Ubuntu 24.04's GLib (2.80) waits for children with waitid(P_PIDFD, ...); without it lightdm exits and
# NetworkManager dispatcher scripts fail ("gmain.c:5802: waitid(pid:N, pidfd=M) failed: Invalid argument").
import re,sys
K="/src/work/workdir/downloads/android_kernel_oneplus_sm8250/"
def edit(path,old,new,count=1):
    s=open(K+path).read()
    assert s.count(old)==count, (path, old[:50], s.count(old))
    open(K+path,"w").write(s.replace(old,new))
edit("include/uapi/linux/wait.h","#define P_PGID\t\t2\n","#define P_PGID\t\t2\n#define P_PIDFD\t\t3\n")
edit("include/linux/pid.h","extern struct pid *find_get_pid(int nr);\n","extern struct pid *find_get_pid(int nr);\nextern struct pid *pidfd_get_pid(unsigned int fd);\n")
edit("kernel/pid.c","#include <linux/anon_inodes.h>\n","#include <linux/anon_inodes.h>\n#include <linux/file.h>\n")
edit("kernel/pid.c","\tfd = ret ?: pidfd_create(p);\n\tput_pid(p);\n\treturn fd;\n}\n",
"\tfd = ret ?: pidfd_create(p);\n\tput_pid(p);\n\treturn fd;\n}\n\n"
"/**\n * pidfd_get_pid() - Get a pid reference from a pidfd.\n * @fd: the pidfd\n *\n * Backport of the 5.4 helper. Returns a referenced struct pid, or an ERR_PTR.\n */\n"
"struct pid *pidfd_get_pid(unsigned int fd)\n{\n\tstruct fd f;\n\tstruct pid *pid;\n\n\tf = fdget(fd);\n\tif (!f.file)\n\t\treturn ERR_PTR(-EBADF);\n\n"
"\tif (f.file->f_op != &pidfd_fops) {\n\t\tfdput(f);\n\t\treturn ERR_PTR(-EBADF);\n\t}\n\n\tpid = get_pid(f.file->private_data);\n\tfdput(f);\n\treturn pid;\n}\n")
edit("kernel/exit.c",
"\tcase P_PID:\n\t\ttype = PIDTYPE_PID;\n\t\tif (upid <= 0)\n\t\t\treturn -EINVAL;\n\t\tbreak;\n\tcase P_PGID:\n\t\ttype = PIDTYPE_PGID;\n\t\tif (upid <= 0)\n\t\t\treturn -EINVAL;\n\t\tbreak;\n\tdefault:\n\t\treturn -EINVAL;\n\t}\n\n\tif (type < PIDTYPE_MAX)\n\t\tpid = find_get_pid(upid);\n\n\two.wo_type\t= type;",
"\tcase P_PID:\n\t\ttype = PIDTYPE_PID;\n\t\tif (upid <= 0)\n\t\t\treturn -EINVAL;\n\n\t\tpid = find_get_pid(upid);\n\t\tbreak;\n\tcase P_PGID:\n\t\ttype = PIDTYPE_PGID;\n\t\tif (upid <= 0)\n\t\t\treturn -EINVAL;\n\n\t\tpid = find_get_pid(upid);\n\t\tbreak;\n"
"\tcase P_PIDFD:\n\t\ttype = PIDTYPE_PID;\n\t\tif (upid < 0)\n\t\t\treturn -EINVAL;\n\n\t\tpid = pidfd_get_pid(upid);\n\t\tif (IS_ERR(pid))\n\t\t\treturn PTR_ERR(pid);\n\t\tbreak;\n"
"\tdefault:\n\t\treturn -EINVAL;\n\t}\n\n\two.wo_type\t= type;")
print("edits applied")
