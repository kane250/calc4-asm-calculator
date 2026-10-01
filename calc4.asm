# ============================================================================
#  calc4.asm —— x86-64 汇编 GTK4 科学计算器（GNU as，Intel 语法）
#
#  功能：
#    * GTK4 窗口：显示屏 + 33 个按钮
#    * 科学函数：sin cos tan √ x^y log ln n! π e
#    * 括号支持：表达式模型（shunting-yard 算法解析）
#    * DEG/RAD 切换
#    * 窗口截图导出（import 命令）
#    * 键盘 + 鼠标双输入
#    * 双精度浮点运算
#
#  构建：as --64 calc4.asm -o calc4.o && gcc -no-pie calc4.o -o calc4 $(pkg-config --libs gtk4) -lm
#  运行：./calc4
# ============================================================================

    .intel_syntax noprefix

# ============================== 常量 ========================================
T_NUMBER = 0
T_PLUS   = 1
T_MINUS  = 2
T_MUL    = 3
T_DIV    = 4
T_POW    = 5
T_LPAREN = 6
T_RPAREN = 7
T_SIN    = 8
T_COS    = 9
T_TAN    = 10
T_SQRT   = 11
T_LOG    = 12
T_LN     = 13
T_FACT   = 14
T_PI     = 15
T_E      = 16
T_PCT    = 17
T_UMINUS = 18

ACT_APPEND   = 0
ACT_EVAL     = 1
ACT_CLEAR    = 2
ACT_BACKSPACE = 3
ACT_SCREENSHOT = 4
ACT_DEG_RAD  = 5

# ============================== 只读数据 ====================================
    .section .rodata

# --- 字符串常量 ---
str_title:      .asciz "汇编科学计算器"
str_zero:       .asciz "0"
str_error:      .asciz "错误"
str_clicked:    .asciz "clicked"
str_destroy:    .asciz "destroy"
str_keypressed: .asciz "key-pressed"
str_markup:     .asciz "<span font_desc='Sans 18' weight='bold'>%s</span>"
str_fmt_g:      .asciz "%.10g"
str_fmt_shot:   .asciz "import -window %lu /tmp/calc_screenshot_%ld.png"
str_shot_msg:   .asciz "截图已保存到 /tmp/\n"

# --- 数学常量 ---
    .align 8
d_pi:       .double 3.14159265358979323846
d_e:        .double 2.71828182845904523536
d_deg2rad:  .double 0.017453292519943295477
d_hundred:  .double 100.0
d_one:      .double 1.0

# --- 按钮标签 ---
str_lbl_deg: .asciz "DEG"
str_lbl_rad: .asciz "RAD"
str_lbl_sin: .asciz "sin"
str_lbl_cos: .asciz "cos"
str_lbl_tan: .asciz "tan"
str_lbl_sqrt: .asciz "√"
str_lbl_pow: .asciz "x^y"
str_lbl_lp:  .asciz "("
str_lbl_rp:  .asciz ")"
str_lbl_log: .asciz "log"
str_lbl_ln:  .asciz "ln"
str_lbl_fact: .asciz "n!"
str_lbl_pi:  .asciz "π"
str_lbl_e2:  .asciz "e"
str_lbl_pct: .asciz "%"
str_lbl_c:   .asciz "C"
str_lbl_bs:  .asciz "⌫"
str_lbl_7:   .asciz "7"
str_lbl_8:   .asciz "8"
str_lbl_9:   .asciz "9"
str_lbl_div: .asciz "÷"
str_lbl_4:   .asciz "4"
str_lbl_5:   .asciz "5"
str_lbl_6:   .asciz "6"
str_lbl_mul: .asciz "×"
str_lbl_1:   .asciz "1"
str_lbl_2:   .asciz "2"
str_lbl_3:   .asciz "3"
str_lbl_sub: .asciz "−"
str_lbl_0:   .asciz "0"
str_lbl_dot: .asciz "."
str_lbl_add: .asciz "+"
str_lbl_eq:  .asciz "="
str_lbl_shot: .asciz "截图"

# --- 追加字符串（内部表示）---
str_app_sin: .asciz "S("
str_app_cos: .asciz "C("
str_app_tan: .asciz "T("
str_app_sqrt: .asciz "Q("
str_app_log: .asciz "G("
str_app_ln:  .asciz "N("
str_app_pow: .asciz "^"
str_app_lp:  .asciz "("
str_app_rp:  .asciz ")"
str_app_fact: .asciz "!"
str_app_pi:  .asciz "P"
str_app_e2:  .asciz "E"
str_app_pct: .asciz "%"
str_app_add: .asciz "+"
str_app_sub: .asciz "-"
str_app_mul: .asciz "*"
str_app_div: .asciz "/"
str_app_dot: .asciz "."
str_app_0:   .asciz "0"
str_app_1:   .asciz "1"
str_app_2:   .asciz "2"
str_app_3:   .asciz "3"
str_app_4:   .asciz "4"
str_app_5:   .asciz "5"
str_app_6:   .asciz "6"
str_app_7:   .asciz "7"
str_app_8:   .asciz "8"
str_app_9:   .asciz "9"

# --- 显示转换字符串 ---
disp_sin:  .asciz "sin"
disp_cos:  .asciz "cos"
disp_tan:  .asciz "tan"
disp_sqrt: .asciz "√"
disp_log:  .asciz "log"
disp_ln:   .asciz "ln"
disp_pi:   .asciz "π"
disp_e:    .asciz "e"
disp_mul:  .asciz "×"
disp_div:  .asciz "÷"
disp_minus: .asciz "−"

# --- 优先级表（按 token 类型索引）---
    .align 1
prec_table:
    .byte 0, 1, 1, 2, 2, 3, 0, 0, 6, 6, 6, 6, 6, 6, 5, 0, 0, 5, 4

# --- 按钮表（33 项 × 32 字节）---
# struct { char *label; int col; int row; char *append; long action; }  // 32 字节/项
    .align 8
btn_table:
    .quad str_lbl_deg;  .long 0; .long 1; .quad 0;           .quad ACT_DEG_RAD    # DEG
    .quad str_lbl_sin;  .long 1; .long 1; .quad str_app_sin;  .quad ACT_APPEND    # sin
    .quad str_lbl_cos;  .long 2; .long 1; .quad str_app_cos;  .quad ACT_APPEND    # cos
    .quad str_lbl_tan;  .long 3; .long 1; .quad str_app_tan;  .quad ACT_APPEND    # tan
    .quad str_lbl_sqrt; .long 0; .long 2; .quad str_app_sqrt; .quad ACT_APPEND    # √
    .quad str_lbl_pow;  .long 1; .long 2; .quad str_app_pow;  .quad ACT_APPEND    # x^y
    .quad str_lbl_lp;   .long 2; .long 2; .quad str_app_lp;   .quad ACT_APPEND    # (
    .quad str_lbl_rp;   .long 3; .long 2; .quad str_app_rp;   .quad ACT_APPEND    # )
    .quad str_lbl_log;  .long 0; .long 3; .quad str_app_log;  .quad ACT_APPEND    # log
    .quad str_lbl_ln;   .long 1; .long 3; .quad str_app_ln;  .quad ACT_APPEND    # ln
    .quad str_lbl_fact; .long 2; .long 3; .quad str_app_fact; .quad ACT_APPEND    # n!
    .quad str_lbl_pi;   .long 3; .long 3; .quad str_app_pi;   .quad ACT_APPEND    # π
    .quad str_lbl_e2;   .long 0; .long 4; .quad str_app_e2;   .quad ACT_APPEND    # e
    .quad str_lbl_pct;  .long 1; .long 4; .quad str_app_pct;  .quad ACT_APPEND    # %
    .quad str_lbl_c;    .long 2; .long 4; .quad 0;           .quad ACT_CLEAR     # C
    .quad str_lbl_bs;   .long 3; .long 4; .quad 0;           .quad ACT_BACKSPACE # ⌫
    .quad str_lbl_7;    .long 0; .long 5; .quad str_app_7;   .quad ACT_APPEND
    .quad str_lbl_8;    .long 1; .long 5; .quad str_app_8;   .quad ACT_APPEND
    .quad str_lbl_9;    .long 2; .long 5; .quad str_app_9;   .quad ACT_APPEND
    .quad str_lbl_div;  .long 3; .long 5; .quad str_app_div;  .quad ACT_APPEND    # ÷
    .quad str_lbl_4;    .long 0; .long 6; .quad str_app_4;   .quad ACT_APPEND
    .quad str_lbl_5;    .long 1; .long 6; .quad str_app_5;   .quad ACT_APPEND
    .quad str_lbl_6;    .long 2; .long 6; .quad str_app_6;   .quad ACT_APPEND
    .quad str_lbl_mul;  .long 3; .long 6; .quad str_app_mul;  .quad ACT_APPEND    # ×
    .quad str_lbl_1;    .long 0; .long 7; .quad str_app_1;   .quad ACT_APPEND
    .quad str_lbl_2;    .long 1; .long 7; .quad str_app_2;   .quad ACT_APPEND
    .quad str_lbl_3;    .long 2; .long 7; .quad str_app_3;   .quad ACT_APPEND
    .quad str_lbl_sub;  .long 3; .long 7; .quad str_app_sub;  .quad ACT_APPEND    # −
    .quad str_lbl_0;    .long 0; .long 8; .quad str_app_0;   .quad ACT_APPEND
    .quad str_lbl_dot;  .long 1; .long 8; .quad str_app_dot;  .quad ACT_APPEND
    .quad str_lbl_add;  .long 2; .long 8; .quad str_app_add;  .quad ACT_APPEND    # +
    .quad str_lbl_eq;   .long 3; .long 8; .quad 0;           .quad ACT_EVAL       # =
    .quad str_lbl_shot; .long 0; .long 9; .quad 0;           .quad ACT_SCREENSHOT # 截图

# ============================== BSS ========================================
    .section .bss
    .align 8
win_ptr:     .space 8
grid_ptr:    .space 8
    .globl label_ptr
label_ptr:   .space 8
deg_btn_ptr: .space 8
loop_ptr:    .space 8

    .globl expr
    .globl expr_len
expr:        .space 512
expr_len:    .space 8
disp_buf:    .space 2048

# token 数组（每个 16 字节：type 4B + pad 4B + value 8B）
    .globl tok_in
    .globl tok_in_cnt
tok_in:      .space 4096
tok_in_cnt:  .space 8
    .globl tok_rpn
    .globl rpn_off
tok_rpn:     .space 4096
rpn_off:     .space 8
tok_op:      .space 4096
op_off:      .space 8

# 值栈（RPN 求值用）
val_stack:   .space 2048
val_sp:      .space 8
val_base:    .space 8

# 状态
result:      .space 8
    .globl deg_mode
deg_mode:    .space 1     # 0=RAD, 1=DEG
    .globl err_flag
err_flag:    .space 1
fresh_flag:  .space 1

# 临时
num_buf:     .space 64
num_start:   .space 8
endptr:      .space 8
key_buf:     .space 2
cur_prec:    .space 4
exit_stat:   .space 4

# ============================== 代码 ========================================
    .section .text
    .globl main
    .globl calc_append
    .globl calc_eval
    .globl calc_clear
    .globl calc_backspace
    .globl refresh_display

# ---------------------------------------------------------------- main ----
main:
    push rbp
    mov  rbp, rsp
    push rbx; push r12; push r13; push r14

    call gtk_init@PLT                     # gtk_init() —— GTK4 无参数

    call gtk_window_new@PLT               # gtk_window_new() —— GTK4 无参数
    mov  [rip+win_ptr], rax

    mov  rdi, rax
    lea  rsi, [rip+str_title]
    call gtk_window_set_title@PLT

    mov  rdi, [rip+win_ptr]
    mov  esi, 380
    mov  edx, 580
    call gtk_window_set_default_size@PLT
    mov  rdi, [rip+win_ptr]
    xor  esi, esi
    call gtk_window_set_resizable@PLT

    # grid
    call gtk_grid_new@PLT
    mov  [rip+grid_ptr], rax
    mov  rdi, rax; mov esi, 6
    call gtk_grid_set_row_spacing@PLT
    mov  rdi, [rip+grid_ptr]; mov esi, 6
    call gtk_grid_set_column_spacing@PLT
    # 边距（GTK4 用 margin 替代 container_set_border_width）
    mov  rdi, [rip+grid_ptr]; mov esi, 10
    call gtk_widget_set_margin_start@PLT
    mov  rdi, [rip+grid_ptr]; mov esi, 10
    call gtk_widget_set_margin_end@PLT
    mov  rdi, [rip+grid_ptr]; mov esi, 10
    call gtk_widget_set_margin_top@PLT
    mov  rdi, [rip+grid_ptr]; mov esi, 10
    call gtk_widget_set_margin_bottom@PLT

    # 显示屏
    lea  rdi, [rip+str_zero]
    call gtk_label_new@PLT
    mov  [rip+label_ptr], rax
    mov  rdi, rax; mov esi, 2              # GTK_ALIGN_END
    call gtk_widget_set_halign@PLT
    mov  rdi, [rip+label_ptr]; mov esi, 1
    call gtk_widget_set_hexpand@PLT
    mov  rdi, [rip+label_ptr]; xor esi, esi
    call gtk_widget_set_vexpand@PLT
    mov  rdi, [rip+label_ptr]; mov esi, 12
    call gtk_widget_set_margin_top@PLT
    mov  rdi, [rip+label_ptr]; mov esi, 8
    call gtk_widget_set_margin_bottom@PLT
    mov  rdi, [rip+grid_ptr]
    mov  rsi, [rip+label_ptr]
    xor  edx, edx; xor ecx, ecx
    mov  r8d, 4; mov r9d, 1
    call gtk_grid_attach@PLT

    # 按钮
    lea  rbx, [rip+btn_table]
    mov  r12d, 33
.Lmk_btn:
    mov  rdi, [rbx]
    call gtk_button_new_with_label@PLT
    mov  r13, rax
    mov  rdi, r13; mov esi, 1
    call gtk_widget_set_hexpand@PLT
    mov  rdi, r13; mov esi, 1
    call gtk_widget_set_vexpand@PLT
    # g_signal_connect(btn, "clicked", on_button_clicked, entry_ptr)
    mov  rdi, r13
    lea  rsi, [rip+str_clicked]
    lea  rdx, [rip+on_button_clicked]
    mov  rcx, rbx                         # data = 按钮表项指针
    xor  r8d, r8d; xor r9d, r9d
    call g_signal_connect_data@PLT
    # grid_attach
    mov  rdi, [rip+grid_ptr]
    mov  rsi, r13
    movsxd edx, dword ptr [rbx+8]         # col
    movsxd ecx, dword ptr [rbx+12]        # row
    mov  r8d, 1                           # width
    cmp  qword ptr [rbx+24], ACT_SCREENSHOT
    jne  .Lmk_w1
    mov  r8d, 4                           # 截图按钮跨 4 列
.Lmk_w1:
    mov  r9d, 1
    call gtk_grid_attach@PLT
    # 保存 DEG 按钮指针
    cmp  qword ptr [rbx+24], ACT_DEG_RAD
    jne  .Lmk_next
    mov  [rip+deg_btn_ptr], r13
.Lmk_next:
    add  rbx, 32
    dec  r12d
    jnz  .Lmk_btn

    # gtk_window_set_child(win, grid) —— GTK4 替代 gtk_container_add
    mov  rdi, [rip+win_ptr]
    mov  rsi, [rip+grid_ptr]
    call gtk_window_set_child@PLT

    # destroy 信号
    mov  rdi, [rip+win_ptr]
    lea  rsi, [rip+str_destroy]
    lea  rdx, [rip+on_destroy]
    xor  ecx, ecx; xor r8d, r8d; xor r9d, r9d
    call g_signal_connect_data@PLT

    # 键盘事件（GTK4 用 EventControllerKey 替代 key-press-event）
    call gtk_event_controller_key_new@PLT
    mov  r14, rax
    mov  rdi, [rip+win_ptr]
    mov  rsi, r14
    call gtk_widget_add_controller@PLT
    mov  rdi, r14
    lea  rsi, [rip+str_keypressed]
    lea  rdx, [rip+on_key_pressed]
    xor  ecx, ecx; xor r8d, r8d; xor r9d, r9d
    call g_signal_connect_data@PLT

    # 初始状态
    mov  byte ptr [rip+deg_mode], 1        # 默认 DEG
    call refresh_display

    # 主循环（GTK4 用 GMainLoop 替代 gtk_main）
    xor  edi, edi; xor esi, esi
    call g_main_loop_new@PLT
    mov  [rip+loop_ptr], rax
    mov  rdi, [rip+win_ptr]
    call gtk_window_present@PLT            # GTK4 替代 gtk_widget_show_all
    mov  rdi, [rip+loop_ptr]
    call g_main_loop_run@PLT

    xor  eax, eax
    pop  r14; pop r13; pop r12; pop rbx; pop rbp
    ret

# ------------------------------------------------------------- 回调 -------
on_destroy:
    push rbp; mov rbp, rsp
    mov  rdi, [rip+loop_ptr]
    call g_main_loop_quit@PLT
    pop  rbp; ret

on_button_clicked:
    # rdi=btn, rsi=data(=btn_table entry ptr)
    # 注意：libffi 以标准 ABI 调用本函数（入口 rsp%16=8）。
    # SysV 要求每个 call 指令前 rsp 16 字节对齐，因此 push 次数须为奇数。
    # push rax 仅作 8 字节填充对齐（rax 为调用者保存寄存器，无需保护）。
    push rbp; mov rbp, rsp
    push rbx
    push rax                                 # 栈对齐填充
    mov  rbx, rsi                           # rbx = 按钮表项
    mov  rax, [rbx+24]                      # action
    cmp  rax, ACT_APPEND; je .Lbc_app
    cmp  rax, ACT_EVAL; je .Lbc_eval
    cmp  rax, ACT_CLEAR; je .Lbc_clear
    cmp  rax, ACT_BACKSPACE; je .Lbc_bs
    cmp  rax, ACT_SCREENSHOT; je .Lbc_shot
    cmp  rax, ACT_DEG_RAD; je .Lbc_deg
    jmp  .Lbc_done
.Lbc_app: mov rdi, [rbx+16]; call calc_append; jmp .Lbc_ref
.Lbc_eval: call calc_eval; jmp .Lbc_ref
.Lbc_clear: call calc_clear; jmp .Lbc_ref
.Lbc_bs: call calc_backspace; jmp .Lbc_ref
.Lbc_deg: call toggle_deg_rad; jmp .Lbc_ref
.Lbc_shot: call do_screenshot; jmp .Lbc_done
.Lbc_ref: call refresh_display
.Lbc_done: pop rax; pop rbx; pop rbp; ret

on_key_pressed:
    # rdi=controller, esi=keyval, edx=keycode, ecx=state, r8=user_data
    # 同 on_button_clicked：入口 rsp%16=8，push 次数须为奇数（rax 为对齐填充）。
    push rbp; mov rbp, rsp
    push rbx
    push rax                                 # 栈对齐填充
    mov  ebx, esi                           # 保存 keyval

    # 主键盘 0-9
    cmp  ebx, 0x30; jb .Lkk_kp
    cmp  ebx, 0x39; ja .Lkk_kp
    mov  [rip+key_buf], bl
    mov  byte ptr [rip+key_buf+1], 0
    lea  rdi, [rip+key_buf]
    call calc_append
    jmp  .Lkk_ref
.Lkk_kp:
    cmp  ebx, 0xffb0; jb .Lkk_oth          # 小键盘 KP_0-KP_9
    cmp  ebx, 0xffb9; ja .Lkk_oth
    sub  ebx, 0xff80
    mov  [rip+key_buf], bl
    mov  byte ptr [rip+key_buf+1], 0
    lea  rdi, [rip+key_buf]
    call calc_append
    jmp  .Lkk_ref
.Lkk_oth:
    cmp  ebx, 0x2b; je .Lkk_s_add
    cmp  ebx, 0x2d; je .Lkk_s_sub
    cmp  ebx, 0x2a; je .Lkk_s_mul
    cmp  ebx, 0x2f; je .Lkk_s_div
    cmp  ebx, 0x5e; je .Lkk_s_pow
    cmp  ebx, 0x28; je .Lkk_s_lp
    cmp  ebx, 0x29; je .Lkk_s_rp
    cmp  ebx, 0x2e; je .Lkk_s_dot
    cmp  ebx, 0x25; je .Lkk_s_pct
    cmp  ebx, 0x21; je .Lkk_s_fact
    cmp  ebx, 0x3d; je .Lkk_eval
    cmp  ebx, 0xff0d; je .Lkk_eval          # Return
    cmp  ebx, 0xff8b; je .Lkk_eval          # KP_Enter
    cmp  ebx, 0xffab; je .Lkk_s_add         # KP_Add
    cmp  ebx, 0xffad; je .Lkk_s_sub         # KP_Subtract
    cmp  ebx, 0xffaa; je .Lkk_s_mul         # KP_Multiply
    cmp  ebx, 0xffaf; je .Lkk_s_div         # KP_Divide
    cmp  ebx, 0xffae; je .Lkk_s_dot         # KP_Decimal
    cmp  ebx, 0xff08; je .Lkk_bs            # BackSpace
    cmp  ebx, 0xffff; je .Lkk_bs            # Delete
    cmp  ebx, 0xff1b; je .Lkk_clear         # Escape
    cmp  ebx, 0x73; je .Lkk_s_sin           # 's'
    cmp  ebx, 0x63; je .Lkk_s_cos           # 'c'
    cmp  ebx, 0x74; je .Lkk_s_tan           # 't'
    cmp  ebx, 0x72; je .Lkk_s_sqrt          # 'r'
    cmp  ebx, 0x6c; je .Lkk_s_log           # 'l'
    cmp  ebx, 0x6e; je .Lkk_s_ln            # 'n'
    cmp  ebx, 0x70; je .Lkk_s_pi            # 'p'
    pop rax; xor  eax, eax; pop rbx; pop rbp; ret   # 未识别 → FALSE

.Lkk_s_add: lea rdi, [rip+str_app_add]; jmp .Lkk_app
.Lkk_s_sub: lea rdi, [rip+str_app_sub]; jmp .Lkk_app
.Lkk_s_mul: lea rdi, [rip+str_app_mul]; jmp .Lkk_app
.Lkk_s_div: lea rdi, [rip+str_app_div]; jmp .Lkk_app
.Lkk_s_pow: lea rdi, [rip+str_app_pow]; jmp .Lkk_app
.Lkk_s_lp:  lea rdi, [rip+str_app_lp]; jmp .Lkk_app
.Lkk_s_rp:  lea rdi, [rip+str_app_rp]; jmp .Lkk_app
.Lkk_s_dot: lea rdi, [rip+str_app_dot]; jmp .Lkk_app
.Lkk_s_pct: lea rdi, [rip+str_app_pct]; jmp .Lkk_app
.Lkk_s_fact: lea rdi, [rip+str_app_fact]; jmp .Lkk_app
.Lkk_s_sin: lea rdi, [rip+str_app_sin]; jmp .Lkk_app
.Lkk_s_cos: lea rdi, [rip+str_app_cos]; jmp .Lkk_app
.Lkk_s_tan: lea rdi, [rip+str_app_tan]; jmp .Lkk_app
.Lkk_s_sqrt: lea rdi, [rip+str_app_sqrt]; jmp .Lkk_app
.Lkk_s_log: lea rdi, [rip+str_app_log]; jmp .Lkk_app
.Lkk_s_ln:  lea rdi, [rip+str_app_ln]; jmp .Lkk_app
.Lkk_s_pi:  lea rdi, [rip+str_app_pi]; jmp .Lkk_app
.Lkk_app:   call calc_append; jmp .Lkk_ref
.Lkk_eval:  call calc_eval; jmp .Lkk_ref
.Lkk_clear: call calc_clear; jmp .Lkk_ref
.Lkk_bs:    call calc_backspace
.Lkk_ref:   call refresh_display
    pop rax; mov  eax, 1; pop rbx; pop rbp; ret      # TRUE

# ------------------------------------------------------------- 截图 -------
do_screenshot:
    push rbp; mov rbp, rsp
    push rbx; push r12
    # 获取 GdkSurface
    mov  rdi, [rip+win_ptr]
    call gtk_native_get_surface@PLT
    mov  rbx, rax
    # 获取 X11 XID
    mov  rdi, rbx
    call gdk_x11_surface_get_xid@PLT
    mov  r12, rax                           # r12 = XID
    # 获取时间戳
    call g_get_real_time@PLT               # rax = microseconds
    # 构建命令
    lea  rdi, [rip+str_fmt_shot]
    mov  rsi, r12                           # %lu = XID
    mov  rdx, rax                           # %ld = timestamp
    xor  eax, eax
    call g_strdup_printf@PLT
    mov  rbx, rax                           # rbx = command string
    # 执行
    mov  rdi, rbx
    xor  esi, esi; xor edx, edx
    lea  rcx, [rip+exit_stat]
    xor  r8d, r8d
    call g_spawn_command_line_sync@PLT
    # 提示
    lea  rdi, [rip+str_shot_msg]
    call g_print@PLT
    # 释放
    mov  rdi, rbx
    call g_free@PLT
    pop  r12; pop rbx; pop rbp; ret

# ------------------------------------------------------------- DEG/RAD ----
toggle_deg_rad:
    push rbp; mov rbp, rsp
    xor  byte ptr [rip+deg_mode], 1
    mov  rdi, [rip+deg_btn_ptr]
    cmp  byte ptr [rip+deg_mode], 0
    je   .Ldr_rad
    lea  rsi, [rip+str_lbl_deg]
    jmp  .Ldr_set
.Ldr_rad:
    lea  rsi, [rip+str_lbl_rad]
.Ldr_set:
    call gtk_button_set_label@PLT
    pop  rbp; ret

# ------------------------------------------------------------- 表达式管理 --
calc_clear:
    push rbp; mov rbp, rsp
    pxor xmm0, xmm0
    movsd [rip+result], xmm0
    mov  qword ptr [rip+expr_len], 0
    mov  byte ptr [rip+expr], 0
    mov  byte ptr [rip+err_flag], 0
    mov  byte ptr [rip+fresh_flag], 0
    pop  rbp; ret

calc_backspace:
    push rbp; mov rbp, rsp
    cmp  byte ptr [rip+err_flag], 0
    je   .Lcb2
    call calc_clear
    pop  rbp; ret
.Lcb2:
    cmp  byte ptr [rip+fresh_flag], 0
    je   .Lcb3
    call calc_clear
    pop  rbp; ret
.Lcb3:
    mov  rax, [rip+expr_len]
    test rax, rax
    jz   .Lcb_done
    dec  rax
    mov  [rip+expr_len], rax
    lea  rcx, [rip+expr]
    mov  byte ptr [rcx+rax], 0
.Lcb_done:
    pop  rbp; ret

calc_append:
    # rdi = 字符串指针
    push rbp; mov rbp, rsp
    push rbx; push r12; push r13; push r14
    mov  rbx, rdi                           # rbx = src

    # 出错状态：先清除（任何输入都重新开始）
    cmp  byte ptr [rip+err_flag], 0
    je   .Lca_noerr
    pxor xmm0, xmm0
    movsd [rip+result], xmm0
    mov  qword ptr [rip+expr_len], 0
    mov  byte ptr [rip+expr], 0
    mov  byte ptr [rip+err_flag], 0
    mov  byte ptr [rip+fresh_flag], 0
.Lca_noerr:
    # fresh 状态：数字/点/左括号/函数/常量 → 先清空；运算符 → 续接
    cmp  byte ptr [rip+fresh_flag], 0
    je   .Lca_append
    mov  al, [rbx]
    cmp  al, '0'; jb .Lca_chk_special
    cmp  al, '9'; jbe .Lca_clear_first
    cmp  al, '.'; je .Lca_clear_first
    cmp  al, '('; je .Lca_clear_first
    cmp  al, 'S'; je .Lca_clear_first
    cmp  al, 'C'; je .Lca_clear_first
    cmp  al, 'T'; je .Lca_clear_first
    cmp  al, 'Q'; je .Lca_clear_first
    cmp  al, 'G'; je .Lca_clear_first
    cmp  al, 'N'; je .Lca_clear_first
    cmp  al, 'P'; je .Lca_clear_first
    cmp  al, 'E'; je .Lca_clear_first
    jmp .Lca_append                        # 运算符/右括号/后缀 → 续接
.Lca_chk_special:
    jmp .Lca_append
.Lca_clear_first:
    mov  qword ptr [rip+expr_len], 0
    mov  byte ptr [rip+expr], 0
    mov  byte ptr [rip+fresh_flag], 0

.Lca_append:
    mov  r12, [rip+expr_len]
    lea  r13, [rip+expr]
    # 计算 src 长度
    xor  ecx, ecx
.Lca_slen:
    cmp  byte ptr [rbx+rcx], 0
    je   .Lca_sdone
    inc  ecx
    jmp  .Lca_slen
.Lca_sdone:
    mov  r14d, ecx                         # r14 = src len
    # 检查容量
    mov  rax, r12
    add  rax, r14
    cmp  rax, 500
    ja   .Lca_ret                          # 超限忽略
    # 复制
    lea  rdi, [r13+r12]
    xor  ecx, ecx
.Lca_copy:
    cmp  ecx, r14d
    jae  .Lca_cdone
    mov  al, [rbx+rcx]
    mov  [rdi+rcx], al
    inc  ecx
    jmp  .Lca_copy
.Lca_cdone:
    add  r12, r14
    mov  [rip+expr_len], r12
    mov  byte ptr [r13+r12], 0
.Lca_ret:
    pop  r14; pop r13; pop r12; pop rbx; pop rbp; ret

calc_eval:
    push rbp; mov rbp, rsp
    push rbx; push r12; push r13; push r14

    # 空表达式 → 0
    cmp  qword ptr [rip+expr_len], 0
    jne  .Lce_go
    pxor xmm0, xmm0
    movsd [rip+result], xmm0
    call result_to_expr
    mov  byte ptr [rip+fresh_flag], 1
    jmp  .Lce_done

.Lce_go:
    call tokenize
    cmp  byte ptr [rip+err_flag], 0
    jne  .Lce_err
    call shunting_yard
    cmp  byte ptr [rip+err_flag], 0
    jne  .Lce_err
    call eval_rpn
    cmp  byte ptr [rip+err_flag], 0
    jne  .Lce_err
    call result_to_expr
    mov  byte ptr [rip+fresh_flag], 1
    jmp  .Lce_done

.Lce_err:
    mov  byte ptr [rip+err_flag], 1
    mov  qword ptr [rip+expr_len], 0
    mov  byte ptr [rip+expr], 0
    mov  byte ptr [rip+fresh_flag], 0

.Lce_done:
    pop  r14; pop r13; pop r12; pop rbx; pop rbp; ret

result_to_expr:
    push rbp; mov rbp, rsp
    push rbx; push r12
    movsd xmm0, [rip+result]
    lea  rdi, [rip+str_fmt_g]
    mov  al, 1
    call g_strdup_printf@PLT
    mov  rbx, rax
    lea  r12, [rip+expr]
    xor  ecx, ecx
.Lrt_c:
    mov  al, [rbx+rcx]
    test al, al
    jz   .Lrt_e
    cmp  rcx, 500
    jae  .Lrt_e
    mov  [r12+rcx], al
    inc  ecx
    jmp  .Lrt_c
.Lrt_e:
    mov  byte ptr [r12+rcx], 0
    mov  [rip+expr_len], rcx
    mov  rdi, rbx
    call g_free@PLT
    pop  r12; pop rbx; pop rbp; ret

# ------------------------------------------------------------- 渲染 -------
refresh_display:
    push rbp; mov rbp, rsp
    push rbx; push r12; push r13; push r14
    xor  r13d, r13d                        # 0=不需释放
    cmp  byte ptr [rip+err_flag], 0
    je   .Lrd_ne
    lea  rbx, [rip+str_error]
    jmp  .Lrd_render
.Lrd_ne:
    cmp  qword ptr [rip+expr_len], 0
    je   .Lrd_zero
    call internal_to_display
    mov  rbx, rax
    mov  r13d, 1
    jmp  .Lrd_render
.Lrd_zero:
    lea  rbx, [rip+str_zero]
.Lrd_render:
    lea  rdi, [rip+str_markup]
    mov  rsi, rbx
    xor  eax, eax
    call g_strdup_printf@PLT
    mov  r12, rax
    mov  rdi, [rip+label_ptr]
    mov  rsi, r12
    call gtk_label_set_markup@PLT
    mov  rdi, r12
    call g_free@PLT
    test r13d, r13d
    jz   .Lrd_d
    mov  rdi, rbx
    call g_free@PLT
.Lrd_d:
    pop  r14; pop r13; pop r12; pop rbx; pop rbp; ret

# 内部表达式 → 显示字符串（堆分配）
internal_to_display:
    push rbp; mov rbp, rsp
    push rbx; push r12; push r13; push r14
    lea  rbx, [rip+expr]
    lea  r12, [rip+disp_buf]
    xor  r13d, r13d
.Litd_l:
    mov  al, [rbx]
    test al, al
    jz   .Litd_end
    cmp  al, 'S'; je .Litd_sin
    cmp  al, 'C'; je .Litd_cos
    cmp  al, 'T'; je .Litd_tan
    cmp  al, 'Q'; je .Litd_sqrt
    cmp  al, 'G'; je .Litd_log
    cmp  al, 'N'; je .Litd_ln
    cmp  al, 'P'; je .Litd_pi
    cmp  al, 'E'; je .Litd_e
    cmp  al, '*'; je .Litd_mul
    cmp  al, '/'; je .Litd_div
    # '-' 保持原样（不转 Unicode），避免结果中的负号被转换
    mov  [r12+r13], al
    inc  r13d
    inc  rbx
    jmp  .Litd_l
.Litd_sin:  lea r14, [rip+disp_sin];  jmp .Litd_cs
.Litd_cos:  lea r14, [rip+disp_cos];  jmp .Litd_cs
.Litd_tan:  lea r14, [rip+disp_tan];  jmp .Litd_cs
.Litd_sqrt: lea r14, [rip+disp_sqrt]; jmp .Litd_cs
.Litd_log:  lea r14, [rip+disp_log];  jmp .Litd_cs
.Litd_ln:   lea r14, [rip+disp_ln];   jmp .Litd_cs
.Litd_pi:   lea r14, [rip+disp_pi];   jmp .Litd_cs
.Litd_e:    lea r14, [rip+disp_e];    jmp .Litd_cs
.Litd_mul:  lea r14, [rip+disp_mul];  jmp .Litd_cs
.Litd_div:  lea r14, [rip+disp_div];  jmp .Litd_cs
.Litd_minus: lea r14, [rip+disp_minus]; jmp .Litd_cs
.Litd_cs:
    lea  rdi, [r12+r13]
    xor  ecx, ecx
.Litd_cs2:
    mov  al, [r14+rcx]
    test al, al
    jz   .Litd_cs3
    mov  [rdi+rcx], al
    inc  ecx
    jmp  .Litd_cs2
.Litd_cs3:
    add  r13d, ecx
    inc  rbx
    jmp  .Litd_l
.Litd_end:
    mov  byte ptr [r12+r13], 0
    mov  rdi, r12
    call g_strdup@PLT
    pop  r14; pop r13; pop r12; pop rbx; pop rbp; ret

# ================================================== 词法分析器 ============
# 输入: expr 字符串 → 输出: tok_in[] + tok_in_cnt
    .globl tokenize
tokenize:
    push rbp; mov rbp, rsp
    push rbx; push r12; push r13; push r14

    lea  rbx, [rip+expr]                   # 扫描指针
    lea  r12, [rip+tok_in]                 # token 数组基址
    xor  r13d, r13d                        # 字节偏移
    mov  r14d, -1                         # 前一个 token 类型（-1 = 无前驱）

.Ltk_l:
    mov  al, [rbx]
    test al, al
    jz   .Ltk_done
    cmp  al, ' '
    je   .Ltk_skip
    cmp  al, '='
    je   .Ltk_skip                          # '=' 在表达式串中无意义（由 ACT_EVAL 触发求值）

    # 数字
    cmp  al, '0'; jb .Ltk_ot
    cmp  al, '9'; jbe .Ltk_num
    cmp  al, '.'; je .Ltk_num
.Ltk_ot:
    cmp  al, '+'; je .Ltk_plus
    cmp  al, '-'; je .Ltk_minus
    cmp  al, '*'; je .Ltk_mul
    cmp  al, '/'; je .Ltk_div
    cmp  al, '^'; je .Ltk_pow
    cmp  al, '('; je .Ltk_lp
    cmp  al, ')'; je .Ltk_rp
    cmp  al, 'S'; je .Ltk_sin
    cmp  al, 'C'; je .Ltk_cos
    cmp  al, 'T'; je .Ltk_tan
    cmp  al, 'Q'; je .Ltk_sqrt
    cmp  al, 'G'; je .Ltk_log
    cmp  al, 'N'; je .Ltk_ln
    cmp  al, '!'; je .Ltk_fact
    cmp  al, 'P'; je .Ltk_pi
    cmp  al, 'E'; je .Ltk_e
    cmp  al, '%'; je .Ltk_pct
    # 未知字符 → 错误
    mov  byte ptr [rip+err_flag], 1
    jmp  .Ltk_done

.Ltk_num:
    mov  [rip+num_start], rbx
    lea  rdx, [rip+num_buf]
    xor  ecx, ecx
.Ltk_ns:
    mov  al, [rbx+rcx]
    test al, al; jz .Ltk_ne
    cmp  al, '.'; je .Ltk_nc                     # '.' 必须在范围检查之前！
    cmp  al, '0'; jb .Ltk_ne
    cmp  al, '9'; jbe .Ltk_nc
    jmp  .Ltk_ne
.Ltk_nc:
    mov  [rdx+rcx], al
    inc  ecx
    jmp  .Ltk_ns
.Ltk_ne:
    mov  byte ptr [rdx+rcx], 0
    lea  rdi, [rip+num_buf]
    lea  rsi, [rip+endptr]
    call g_ascii_strtod@PLT
    # 检查是否消耗了字符
    mov  rax, [rip+endptr]
    lea  rcx, [rip+num_buf]
    cmp  rax, rcx
    jne  .Ltk_nok
    # strtod 未能解析：检查是否 '.'
    mov  al, [rcx]
    cmp  al, '.'
    jne  .Ltk_nerr
    pxor xmm0, xmm0
    mov  rbx, [rip+num_start]
    inc  rbx
    jmp  .Ltk_nstore
.Ltk_nok:
    sub  rax, rcx                         # consumed count
    mov  rbx, [rip+num_start]
    add  rbx, rax
.Ltk_nstore:
    mov  dword ptr [r12+r13], T_NUMBER
    movsd [r12+r13+8], xmm0
    add  r13, 16
    mov  r14d, T_NUMBER
    jmp  .Ltk_l
.Ltk_nerr:
    mov  byte ptr [rip+err_flag], 1
    jmp  .Ltk_done

.Ltk_plus:
    mov  dword ptr [r12+r13], T_PLUS
    add  r13, 16; mov r14d, T_PLUS
    inc  rbx; jmp .Ltk_l
.Ltk_mul:
    mov  dword ptr [r12+r13], T_MUL
    add  r13, 16; mov r14d, T_MUL
    inc  rbx; jmp .Ltk_l
.Ltk_div:
    mov  dword ptr [r12+r13], T_DIV
    add  r13, 16; mov r14d, T_DIV
    inc  rbx; jmp .Ltk_l
.Ltk_pow:
    mov  dword ptr [r12+r13], T_POW
    add  r13, 16; mov r14d, T_POW
    inc  rbx; jmp .Ltk_l
.Ltk_lp:
    mov  dword ptr [r12+r13], T_LPAREN
    add  r13, 16; mov r14d, T_LPAREN
    inc  rbx; jmp .Ltk_l
.Ltk_rp:
    mov  dword ptr [r12+r13], T_RPAREN
    add  r13, 16; mov r14d, T_RPAREN
    inc  rbx; jmp .Ltk_l
.Ltk_sin:
    mov  dword ptr [r12+r13], T_SIN
    add  r13, 16; mov r14d, T_SIN
    inc  rbx; jmp .Ltk_l
.Ltk_cos:
    mov  dword ptr [r12+r13], T_COS
    add  r13, 16; mov r14d, T_COS
    inc  rbx; jmp .Ltk_l
.Ltk_tan:
    mov  dword ptr [r12+r13], T_TAN
    add  r13, 16; mov r14d, T_TAN
    inc  rbx; jmp .Ltk_l
.Ltk_sqrt:
    mov  dword ptr [r12+r13], T_SQRT
    add  r13, 16; mov r14d, T_SQRT
    inc  rbx; jmp .Ltk_l
.Ltk_log:
    mov  dword ptr [r12+r13], T_LOG
    add  r13, 16; mov r14d, T_LOG
    inc  rbx; jmp .Ltk_l
.Ltk_ln:
    mov  dword ptr [r12+r13], T_LN
    add  r13, 16; mov r14d, T_LN
    inc  rbx; jmp .Ltk_l
.Ltk_fact:
    mov  dword ptr [r12+r13], T_FACT
    add  r13, 16; mov r14d, T_FACT
    inc  rbx; jmp .Ltk_l
.Ltk_pi:
    mov  dword ptr [r12+r13], T_PI
    add  r13, 16; mov r14d, T_PI
    inc  rbx; jmp .Ltk_l
.Ltk_e:
    mov  dword ptr [r12+r13], T_E
    add  r13, 16; mov r14d, T_E
    inc  rbx; jmp .Ltk_l
.Ltk_pct:
    mov  dword ptr [r12+r13], T_PCT
    add  r13, 16; mov r14d, T_PCT
    inc  rbx; jmp .Ltk_l

.Ltk_minus:
    # 判断一元/二元减号
    # 一元：前一个 token 是 none(-1), LPAREN, 或运算符(1-5,18)
    cmp  r14d, -1
    je   .Ltk_uminus
    cmp  r14d, T_LPAREN
    je   .Ltk_uminus
    cmp  r14d, T_PLUS
    je   .Ltk_uminus
    cmp  r14d, T_MINUS
    je   .Ltk_uminus
    cmp  r14d, T_MUL
    je   .Ltk_uminus
    cmp  r14d, T_DIV
    je   .Ltk_uminus
    cmp  r14d, T_POW
    je   .Ltk_uminus
    cmp  r14d, T_UMINUS
    je   .Ltk_uminus
    # 二元减号
    mov  dword ptr [r12+r13], T_MINUS
    add  r13, 16; mov r14d, T_MINUS
    inc  rbx; jmp .Ltk_l
.Ltk_uminus:
    mov  dword ptr [r12+r13], T_UMINUS
    add  r13, 16; mov r14d, T_UMINUS
    inc  rbx; jmp .Ltk_l

.Ltk_skip:
    inc  rbx; jmp .Ltk_l

.Ltk_done:
    mov  rax, r13
    shr  rax, 4                            # token count = bytes / 16
    mov  [rip+tok_in_cnt], rax
    pop  r14; pop r13; pop r12; pop rbx; pop rbp; ret

# ================================================== Shunting-Yard ===========
# 输入: tok_in[], tok_in_cnt → 输出: tok_rpn[], rpn_off
    .globl shunting_yard
shunting_yard:
    push rbp; mov rbp, rsp
    push rbx; push r12; push r13; push r14; push r15

    lea  rbx, [rip+tok_in]
    mov  r12, [rip+tok_in_cnt]
    imul r12, r12, 16                      # 总字节数
    xor  r13d, r13d                        # 输入偏移
    mov  qword ptr [rip+rpn_off], 0
    mov  qword ptr [rip+op_off], 0
    lea  r14, [rip+tok_rpn]               # r14 = RPN base
    lea  r15, [rip+tok_op]                # r15 = op stack base

.Lsy_l:
    cmp  r13, r12
    jae  .Lsy_drain                        # 处理完毕 → 排空栈

    mov  eax, [rbx+r13]                    # token type

    # NUMBER, PI, E → 直接输出
    cmp  eax, T_NUMBER; je .Lsy_out
    cmp  eax, T_PI; je .Lsy_out
    cmp  eax, T_E; je .Lsy_out

    # 左括号 → 压栈（必须先于函数范围检查！T_LPAREN=6 < T_SIN=8）
    cmp  eax, T_LPAREN; je .Lsy_push_op

    # 右括号 → 弹出直到左括号（必须先于函数范围检查！T_RPAREN=7 < T_SIN=8）
    cmp  eax, T_RPAREN; je .Lsy_rparen

    # 函数(8-13) → 压栈
    cmp  eax, T_SIN; jb .Lsy_chk_op
    cmp  eax, T_LN; jbe .Lsy_push_func

.Lsy_chk_op:
    # 运算符: PLUS,MINUS,MUL,DIV,POW,FACT,PCT,UMINUS
    # 获取当前优先级
    lea  rcx, [rip+prec_table]
    movzx ecx, byte ptr [rcx+rax]         # ecx = cur precedence
    mov  [rip+cur_prec], ecx                # save cur prec to BSS

    # 判断右结合（POW=5, UMINUS=18）
    mov  edx, 0                            # 0 = 左结合
    cmp  eax, T_POW; je .Lsy_rassoc
    cmp  eax, T_UMINUS; je .Lsy_rassoc
    jmp  .Lsy_pop_loop
.Lsy_rassoc:
    mov  edx, 1                            # 1 = 右结合
.Lsy_pop_loop:
    # 检查栈空
    mov  rax, [rip+op_off]
    test rax, rax
    jz   .Lsy_push_op2
    # 获取栈顶类型
    sub  rax, 16
    mov  esi, [r15+rax]            # top type
    # 左括号 → 停止
    cmp  esi, T_LPAREN; je .Lsy_push_op2
    # 函数 → 停止（函数只由右括号弹出）
    cmp  esi, T_SIN; jb .Lsy_pop_chk
    cmp  esi, T_LN; jbe .Lsy_push_op2
.Lsy_pop_chk:
    # 获取栈顶优先级
    lea  rcx, [rip+prec_table]
    movzx ecx, byte ptr [rcx+rsi]         # top prec
    # 左结合: top_prec >= cur_prec → 弹出
    # 右结合: top_prec > cur_prec → 弹出
    cmp  edx, 0
    je   .Lsy_left
    # 右结合
    cmp  ecx, dword ptr [rip+cur_prec]
    jle  .Lsy_push_op2                    # top_prec <= cur_prec → 停止
    jmp  .Lsy_do_pop
.Lsy_left:
    cmp  ecx, dword ptr [rip+cur_prec]
    jl   .Lsy_push_op2                    # top_prec < cur_prec → 停止
.Lsy_do_pop:
    # 弹出栈顶到 RPN 输出
    mov  rax, [rip+op_off]
    sub  rax, 16
    # 复制 16 字节
    mov  rcx, [r15+rax]
    mov  rdx, [r15+rax+8]
    mov  rdi, [rip+rpn_off]
    mov  [r14+rdi], rcx
    mov  [r14+rdi+8], rdx
    add  rdi, 16
    mov  [rip+rpn_off], rdi
    mov  [rip+op_off], rax
    jmp  .Lsy_pop_loop

.Lsy_push_op2:
    # 当前运算符压栈
    mov  rax, [rip+op_off]
    mov  ecx, [rbx+r13]                   # type
    mov  [r15+rax], ecx
    movsd xmm0, [rbx+r13+8]
    movsd [r15+rax+8], xmm0
    add  rax, 16
    mov  [rip+op_off], rax
    add  r13, 16
    jmp  .Lsy_l

.Lsy_push_func:
    jmp  .Lsy_push_op2                    # 函数也压栈（同运算符路径）

.Lsy_push_op:
    jmp  .Lsy_push_op2                    # 左括号也压栈

.Lsy_out:
    # 直接输出到 RPN
    mov  rax, [rip+rpn_off]
    mov  ecx, [rbx+r13]
    mov  [r14+rax], ecx
    movsd xmm0, [rbx+r13+8]
    movsd [r14+rax+8], xmm0
    add  rax, 16
    mov  [rip+rpn_off], rax
    add  r13, 16
    jmp  .Lsy_l

.Lsy_rparen:
    # 弹出运算符直到左括号
    mov  rax, [rip+op_off]
    test rax, rax
    jz   .Lsy_err                          # 栈空 → 括号不匹配
    sub  rax, 16
    mov  esi, [r15+rax]
    cmp  esi, T_LPAREN
    je   .Lsy_rp_found                    # 找到左括号
    # 弹出到 RPN
    mov  rcx, [r15+rax]
    mov  rdx, [r15+rax+8]
    mov  rdi, [rip+rpn_off]
    mov  [r14+rdi], rcx
    mov  [r14+rdi+8], rdx
    add  rdi, 16
    mov  [rip+rpn_off], rdi
    mov  [rip+op_off], rax
    jmp  .Lsy_rparen
.Lsy_rp_found:
    # 弹出并丢弃左括号
    mov  [rip+op_off], rax
    # 如果栈顶是函数 → 弹出到 RPN
    mov  rax, [rip+op_off]
    test rax, rax
    jz   .Lsy_rp_done
    sub  rax, 16
    mov  esi, [r15+rax]
    cmp  esi, T_SIN; jb .Lsy_rp_done
    cmp  esi, T_LN; jbe .Lsy_rp_func
    jmp  .Lsy_rp_done
.Lsy_rp_func:
    mov  rcx, [r15+rax]
    mov  rdx, [r15+rax+8]
    mov  rdi, [rip+rpn_off]
    mov  [r14+rdi], rcx
    mov  [r14+rdi+8], rdx
    add  rdi, 16
    mov  [rip+rpn_off], rdi
    mov  [rip+op_off], rax
.Lsy_rp_done:
    add  r13, 16
    jmp  .Lsy_l

.Lsy_err:
    mov  byte ptr [rip+err_flag], 1
    jmp  .Lsy_done

.Lsy_drain:
    # 排空运算符栈
    mov  rax, [rip+op_off]
    test rax, rax
    jz   .Lsy_done
    sub  rax, 16
    mov  esi, [r15+rax]
    cmp  esi, T_LPAREN
    je   .Lsy_err                          # 残留左括号 → 错误
    # 弹出到 RPN
    mov  rcx, [r15+rax]
    mov  rdx, [r15+rax+8]
    mov  rdi, [rip+rpn_off]
    mov  [r14+rdi], rcx
    mov  [r14+rdi+8], rdx
    add  rdi, 16
    mov  [rip+rpn_off], rdi
    mov  [rip+op_off], rax
    jmp  .Lsy_drain

.Lsy_done:
    pop  r15; pop r14; pop r13; pop r12; pop rbx; pop rbp; ret

# ================================================== RPN 求值 ===============
    .globl eval_rpn
eval_rpn:
    # 本函数调用 libm（sin/cos/tan/sqrt/pow/log10/log）：
    # 入口 rsp%16=8，push 次数须为奇数，否则调用点错位（违反 SysV ABI）。
    push rbp; mov rbp, rsp
    push rbx; push r12; push r13
    push rax                                 # 栈对齐填充

    lea  rbx, [rip+tok_rpn]
    mov  r12, [rip+rpn_off]                # 总字节数
    xor  r13d, r13d                        # 偏移

    lea  rax, [rip+val_stack]
    mov  [rip+val_base], rax
    mov  qword ptr [rip+val_sp], 0

.Ler_l:
    cmp  r13, r12
    jae  .Ler_done
    mov  eax, [rbx+r13]                    # token type

    cmp  eax, T_NUMBER; je .Ler_num
    cmp  eax, T_PI; je .Ler_pi
    cmp  eax, T_E; je .Ler_e
    cmp  eax, T_PLUS; je .Ler_add
    cmp  eax, T_MINUS; je .Ler_sub
    cmp  eax, T_MUL; je .Ler_mul
    cmp  eax, T_DIV; je .Ler_div
    cmp  eax, T_POW; je .Ler_pow
    cmp  eax, T_UMINUS; je .Ler_um
    cmp  eax, T_FACT; je .Ler_fact
    cmp  eax, T_PCT; je .Ler_pct
    cmp  eax, T_SIN; je .Ler_sin
    cmp  eax, T_COS; je .Ler_cos
    cmp  eax, T_TAN; je .Ler_tan
    cmp  eax, T_SQRT; je .Ler_sqrt
    cmp  eax, T_LOG; je .Ler_log
    cmp  eax, T_LN; je .Ler_ln
    mov  byte ptr [rip+err_flag], 1
    jmp  .Ler_done

.Ler_num:
    call push_tok_val
    add  r13, 16; jmp .Ler_l
.Ler_pi:
    movsd xmm0, [rip+d_pi]
    call push_xmm0
    add  r13, 16; jmp .Ler_l
.Ler_e:
    movsd xmm0, [rip+d_e]
    call push_xmm0
    add  r13, 16; jmp .Ler_l
.Ler_add:
    call pop_two
    cmp  byte ptr [rip+err_flag], 0; jne .Ler_done
    addsd xmm0, xmm1
    call push_xmm0
    add  r13, 16; jmp .Ler_l
.Ler_sub:
    call pop_two
    cmp  byte ptr [rip+err_flag], 0; jne .Ler_done
    subsd xmm0, xmm1
    call push_xmm0
    add  r13, 16; jmp .Ler_l
.Ler_mul:
    call pop_two
    cmp  byte ptr [rip+err_flag], 0; jne .Ler_done
    mulsd xmm0, xmm1
    call push_xmm0
    add  r13, 16; jmp .Ler_l
.Ler_div:
    call pop_two
    cmp  byte ptr [rip+err_flag], 0; jne .Ler_done
    pxor xmm2, xmm2
    ucomisd xmm1, xmm2
    jp  .Ler_div_ok                        # NaN → 正常除（结果 NaN）
    je  .Ler_err                          # 除零 → 错误
.Ler_div_ok:
    divsd xmm0, xmm1
    call push_xmm0
    add  r13, 16; jmp .Ler_l
.Ler_pow:
    call pop_two
    cmp  byte ptr [rip+err_flag], 0; jne .Ler_done
    call pow@PLT
    call push_xmm0
    add  r13, 16; jmp .Ler_l
.Ler_um:
    call pop_one
    cmp  byte ptr [rip+err_flag], 0; jne .Ler_done
    pxor xmm1, xmm1
    subsd xmm1, xmm0
    movsd xmm0, xmm1
    call push_xmm0
    add  r13, 16; jmp .Ler_l
.Ler_fact:
    call pop_one
    cmp  byte ptr [rip+err_flag], 0; jne .Ler_done
    call do_factorial
    call push_xmm0
    add  r13, 16; jmp .Ler_l
.Ler_pct:
    call pop_one
    cmp  byte ptr [rip+err_flag], 0; jne .Ler_done
    movsd xmm1, [rip+d_hundred]
    divsd xmm0, xmm1
    call push_xmm0
    add  r13, 16; jmp .Ler_l
.Ler_sin:
    call pop_one
    cmp  byte ptr [rip+err_flag], 0; jne .Ler_done
    cmp  byte ptr [rip+deg_mode], 0
    je  .Ler_sin_r
    mulsd xmm0, [rip+d_deg2rad]
.Ler_sin_r:
    call sin@PLT
    call push_xmm0
    add  r13, 16; jmp .Ler_l
.Ler_cos:
    call pop_one
    cmp  byte ptr [rip+err_flag], 0; jne .Ler_done
    cmp  byte ptr [rip+deg_mode], 0
    je  .Ler_cos_r
    mulsd xmm0, [rip+d_deg2rad]
.Ler_cos_r:
    call cos@PLT
    call push_xmm0
    add  r13, 16; jmp .Ler_l
.Ler_tan:
    call pop_one
    cmp  byte ptr [rip+err_flag], 0; jne .Ler_done
    cmp  byte ptr [rip+deg_mode], 0
    je  .Ler_tan_r
    mulsd xmm0, [rip+d_deg2rad]
.Ler_tan_r:
    call tan@PLT
    call push_xmm0
    add  r13, 16; jmp .Ler_l
.Ler_sqrt:
    call pop_one
    cmp  byte ptr [rip+err_flag], 0; jne .Ler_done
    call sqrt@PLT
    call push_xmm0
    add  r13, 16; jmp .Ler_l
.Ler_log:
    call pop_one
    cmp  byte ptr [rip+err_flag], 0; jne .Ler_done
    call log10@PLT
    call push_xmm0
    add  r13, 16; jmp .Ler_l
.Ler_ln:
    call pop_one
    cmp  byte ptr [rip+err_flag], 0; jne .Ler_done
    call log@PLT
    call push_xmm0
    add  r13, 16; jmp .Ler_l

.Ler_err:
    mov  byte ptr [rip+err_flag], 1
    jmp  .Ler_done

.Ler_done:
    # 检查值栈是否恰好一个值
    cmp  qword ptr [rip+val_sp], 8
    jne  .Ler_err2
    mov  rcx, [rip+val_base]
    movsd xmm0, [rcx]
    # NaN 检查（ucomisd 自比较，无序即 NaN，如 Q(-1) 或 G(0)）
    ucomisd xmm0, xmm0
    jp   .Ler_err2
    movsd [rip+result], xmm0
    jmp  .Ler_ret
.Ler_err2:
    mov  byte ptr [rip+err_flag], 1
.Ler_ret:
    pop  rax; pop  r13; pop r12; pop rbx; pop rbp; ret

# --- 值栈辅助函数 ---
push_tok_val:
    # 将当前 token 的 value 压栈
    mov  rax, [rip+val_sp]
    mov  rcx, [rip+val_base]
    movsd xmm0, [rbx+r13+8]
    movsd [rcx+rax], xmm0
    add  rax, 8
    mov  [rip+val_sp], rax
    ret

push_xmm0:
    mov  rax, [rip+val_sp]
    mov  rcx, [rip+val_base]
    movsd [rcx+rax], xmm0
    add  rax, 8
    mov  [rip+val_sp], rax
    ret

pop_one:
    mov  rax, [rip+val_sp]
    test rax, rax
    jz   .Lpo_err
    sub  rax, 8
    mov  [rip+val_sp], rax
    mov  rcx, [rip+val_base]
    movsd xmm0, [rcx+rax]
    ret
.Lpo_err:
    mov  byte ptr [rip+err_flag], 1
    pxor xmm0, xmm0
    ret

pop_two:
    mov  rax, [rip+val_sp]
    cmp  rax, 16
    jb   .Lpt_err
    sub  rax, 8
    mov  rcx, [rip+val_base]
    movsd xmm1, [rcx+rax]                 # xmm1 = b (top)
    sub  rax, 8
    movsd xmm0, [rcx+rax]                 # xmm0 = a (below)
    mov  [rip+val_sp], rax
    ret
.Lpt_err:
    mov  byte ptr [rip+err_flag], 1
    pxor xmm0, xmm0
    pxor xmm1, xmm1
    ret

# --- 阶乘 ---
do_factorial:
    # xmm0 = input (double) → xmm0 = n!
    cvttsd2si rax, xmm0                   # rax = (long long)n
    cvtsi2sd xmm1, rax                    # xmm1 = (double)rax
    ucomisd xmm0, xmm1
    jne  .Ldf_err                          # 非整数
    test rax, rax
    js   .Ldf_err                          # 负数
    cmp  rax, 170
    ja   .Ldf_err                          # 太大
    mov  rcx, rax                          # n
    movsd xmm0, [rip+d_one]               # result = 1.0
    mov  rax, 2
.Ldf_loop:
    cmp  rax, rcx
    jg   .Ldf_done
    cvtsi2sd xmm1, rax
    mulsd xmm0, xmm1
    inc  rax
    jmp  .Ldf_loop
.Ldf_done:
    ret
.Ldf_err:
    mov  byte ptr [rip+err_flag], 1        # 负数/非整数/超界 → 错误
    mov  rax, 0x7FF8000000000000           # NaN
    movq xmm0, rax
    ret
