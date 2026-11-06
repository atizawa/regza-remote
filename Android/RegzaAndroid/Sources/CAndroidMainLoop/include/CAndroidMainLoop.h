// Android のメインスレッドの Looper に、libdispatch の main queue (Swift の MainActor) を回させるための宣言
#ifndef CANDROIDMAINLOOP_H
#define CANDROIDMAINLOOP_H

#include <android/looper.h>

// libdispatch が main queue に仕事が来たことを知らせる eventfd と、溜まった仕事を片づける関数。
// 公開のヘッダーにはないが、Linux 版の Foundation (CoreFoundation の RunLoop) が main queue を回すのに使っている。
// Swift SDK の版を上げたら、まだ使えるかを確かめる
int _dispatch_get_main_queue_handle_4CF(void);
void _dispatch_main_queue_callback_4CF(void *msg);

#endif
