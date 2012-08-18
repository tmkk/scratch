#include <stdio.h>
#include <unistd.h>
#include <math.h>
#include <stdlib.h>

static inline double combination(int n, int m)
{
	if(m==0) return 1;
	int i;
	double result = 1;
	if(m>n-m) m=n-m;
	for(i=0;i<m;i++) {
		result *= n--;
	}
	while(m) result /= m--;
	return result;
}

int main(int argc, char *argv[])
{
	if(argc<3) return 0;
	
	int total = atoi(argv[2]);
	int correct = atoi(argv[1]);
	double n=1;
	
	int i;
	for(i=0;i<total-correct;i++) {
		n += combination(total,i+1);
	}
	
	printf("%.10f\n",(double)n/pow(2,total));
	return 0;
}