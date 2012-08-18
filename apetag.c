#include <stdio.h>
#include <stdlib.h>

int main(int argc, char *argv[])
{
	if(argc<2) return 0;
	FILE *fp = fopen(argv[1], "rb");
	
	int tmp,n,i,j;
	char buffer[1024];
	fseeko(fp,12,SEEK_CUR);
	fread(&tmp,1,4,fp);
	fprintf(stderr,"tag size:%d\n",tmp);
	fread(&tmp,1,4,fp);
	n=tmp;
	fprintf(stderr,"tag count:%d\n",tmp);
	fread(&tmp,1,4,fp);
	fprintf(stderr,"flag:%08x\n",tmp);
	fseeko(fp,8,SEEK_CUR);
	
	for(i=0;i<n;i++) {
		int size;
		fread(&size,1,4,fp);
		fprintf(stderr,"item bytes:%d\n",size);
		fread(&tmp,1,4,fp);
		fprintf(stderr,"item flag:%08x\n",tmp);
		for(j=0;;j++) {
			fread(&buffer[j],1,1,fp);
			if(!buffer[j]) break;
		}
		char *buf = malloc(size+1);
		fread(buf,1,size,fp);
		buf[size] = 0;
		fprintf(stderr,"%s = %s\n",buffer,buf);
	}
	return 0;
}