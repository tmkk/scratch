#include <stdio.h>
#include <mach/thread_policy.h>
#include <mach/mach.h>

int main(void)
{
	int ptr[8];
	long long start, end;
	struct thread_affinity_policy        policy;
	policy.affinity_tag = 1;
	thread_policy_set(
                         mach_thread_self(), THREAD_AFFINITY_POLICY,
                         (thread_policy_t) &policy,
                         THREAD_AFFINITY_POLICY_COUNT);
	__asm__ (
		"movl		$100000000, %%ecx	\n\t"
		"rdtsc						\n\t"
		"shlq		$32, %%rdx		\n\t"
		"movq		%%rax, %0		\n\t"
		"orq		%%rdx, %0		\n\t"
		".align 4					\n\t"
		"1:							\n\t"
		"xorl		%%eax, %%eax	\n\t"
		
		"decl		%%ecx			\n\t"
		"jnz		1b				\n\t"
		"rdtsc						\n\t"
		"shlq		$32, %%rdx		\n\t"
		"movq		%%rax, %1		\n\t"
		"orq		%%rdx, %1		\n\t"
		: "=&r" (start), "=&r" (end)
		: "r" (ptr)
		: "%eax", "%edx", "%ecx"
		);
	
	fprintf(stderr,"%f clk/loop\n",(double)(end-start)/100000000);
	return 0;
}