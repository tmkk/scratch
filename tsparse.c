#include <stdio.h>
#include <libkern/OSByteOrder.h>

int main(int argc, char *argv[])
{
	FILE *fp = fopen(argv[1],"rb");
	int pmt_pid = -1;
	int vid_pid = -1;
	int aud_pid = -1;
	int ecm_pid = -1;
    int ecm_found = 0;
    int trmp_pid = -1;
	
	while(1) {
		if(fgetc(fp) == 0x47) {
			unsigned char header[3];
			fread(header,1,3,fp);
			int adaptation_field_control = (header[2]>>4)&0x3;
			int pid = ((unsigned int)(header[0]&0x1f)<<8)|header[1];
			int payload_unit_start_indicator = (header[0]>>6)&0x1;
			
			/*if(pid != vid_pid && pid != aud_pid) {
				fprintf(stderr,"PID: 0x%x\n",pid);
				fprintf(stderr,"  transport_error_indicator: %d\n",header[0]>>7);
				fprintf(stderr,"  payload_unit_start_indicator: %d\n",payload_unit_start_indicator);
				fprintf(stderr,"  transport_priority: %d\n",(header[0]>>5)&0x1);
				fprintf(stderr,"  transport_scramble_control: 0x%x\n",(header[2]>>6)&0x3);
				fprintf(stderr,"  adaptation_field_control: 0x%x\n",adaptation_field_control);
				fprintf(stderr,"  counter: %d\n",header[2]&0xf);
			}*/
			
			if(pid == 0) {
				fprintf(stderr,"PID: 0x%x (PAT)\n",pid);
				fprintf(stderr,"  adaptation_field_control: 0x%x\n",adaptation_field_control);
				fprintf(stderr,"  payload_unit_start_indicator: %d\n",payload_unit_start_indicator);
				off_t packet_beginning = ftello(fp);
				if(adaptation_field_control & 0x2) {
					fseeko(fp,fgetc(fp),SEEK_CUR);
				}
				if(payload_unit_start_indicator) {
					 /* 1 byte pointer_field exists at the beginning of the payload */
					fseeko(fp,1,SEEK_CUR);
				}
				unsigned short section_length;
				fseeko(fp,1,SEEK_CUR);
				fread(&section_length,2,1,fp);
				section_length = OSSwapBigToHostInt16(section_length) & 0xfff;
				fseeko(fp,5,SEEK_CUR);
				int table_count = (section_length - 4 - 3 - 2) / 4;
				int i;
				for(i=0;i<table_count;i++) {
					unsigned short pno,pid;
					fread(&pno,2,1,fp);
					fread(&pid,2,1,fp);
					pno = OSSwapBigToHostInt16(pno);
					pid = OSSwapBigToHostInt16(pid) & 0x1fff;
					if(pno == 0) {
						fprintf(stderr,"    NIT PID : 0x%04x\n",pid);
					}
					else {
						fprintf(stderr,"    Program 0x%04x PMT PID : 0x%04x\n",pno,pid);
						pmt_pid = pid;
					}
				}
				fseeko(fp,packet_beginning,SEEK_SET);
			}
			else if(pid == 1) {
				fprintf(stderr,"PID: 0x%x (CAT)\n",pid);
				fprintf(stderr,"  adaptation_field_control: 0x%x\n",adaptation_field_control);
				fprintf(stderr,"  payload_unit_start_indicator: %d\n",payload_unit_start_indicator);
				off_t packet_beginning = ftello(fp);
				if(adaptation_field_control & 0x2) {
					fseeko(fp,fgetc(fp),SEEK_CUR);
				}
				if(payload_unit_start_indicator) {
					 /* 1 byte pointer_field exists at the beginning of the payload */
					fseeko(fp,1,SEEK_CUR);
				}
				unsigned short section_length;
				fseeko(fp,1,SEEK_CUR);
				fread(&section_length,2,1,fp);
				section_length = OSSwapBigToHostInt16(section_length) & 0xfff;
				fseeko(fp,5,SEEK_CUR);
				section_length -= 5 + 4;
				int read = 0;
				while(read < section_length) {
					unsigned char tag;
					unsigned char length;
					unsigned short ca_system_id;
					unsigned short pid;
					fread(&tag,1,1,fp);
					fread(&length,1,1,fp);
					fread(&ca_system_id,2,1,fp);
					fread(&pid,2,1,fp);
					ca_system_id = OSSwapBigToHostInt16(ca_system_id);
					pid = OSSwapBigToHostInt16(pid) & 0x1fff;
					if(tag == 0x09) {
						fprintf(stderr,"    EMM PID : 0x%04x\n",pid);
					}
					else if(tag == 0xf6) {
						fprintf(stderr,"    TRMP system ID : 0x%04x\n",ca_system_id);
						fprintf(stderr,"    TRMP PID : 0x%04x\n",pid);
					}
					fseeko(fp,length-2,SEEK_CUR);
					read += 2 + length;
				}
				fseeko(fp,packet_beginning,SEEK_SET);
			}
			else if(pid == pmt_pid) {
				fprintf(stderr,"PID: 0x%x (PMT)\n",pid);
				fprintf(stderr,"  adaptation_field_control: 0x%x\n",adaptation_field_control);
				fprintf(stderr,"  payload_unit_start_indicator: %d\n",payload_unit_start_indicator);
				off_t packet_beginning = ftello(fp);
				if(adaptation_field_control & 0x2) {
					fseeko(fp,fgetc(fp),SEEK_CUR);
				}
				if(payload_unit_start_indicator) {
					 /* 1 byte pointer_field exists at the beginning of the payload */
					fseeko(fp,1,SEEK_CUR);
				}
				unsigned short section_length;
				fseeko(fp,1,SEEK_CUR);
				fread(&section_length,2,1,fp);
				section_length = OSSwapBigToHostInt16(section_length) & 0xfff;
				fseeko(fp,7,SEEK_CUR);
				unsigned short program_info_length;
				fread(&program_info_length,2,1,fp);
				program_info_length = OSSwapBigToHostInt16(program_info_length) & 0xfff;
				int read = 0;
				while(read < program_info_length) {
					unsigned char tag;
					unsigned char length;
					fread(&tag,1,1,fp);
					fread(&length,1,1,fp);
					if(tag == 0x09) {
						unsigned short pid;
						fseeko(fp,2,SEEK_CUR);
						fread(&pid,2,1,fp);
						ecm_pid = OSSwapBigToHostInt16(pid) & 0x1fff;
						fseeko(fp,-4,SEEK_CUR);
						fprintf(stderr,"    ECM PID : 0x%04x\n",ecm_pid);
                    }
                    else if(tag == 0xf6) {
						unsigned short pid;
                        fread(&pid,2,1,fp);
                        fprintf(stderr,"    TRMP system ID : 0x%04x\n",OSSwapBigToHostInt16(pid));
						fread(&pid,2,1,fp);
						trmp_pid = OSSwapBigToHostInt16(pid) & 0x1fff;
						fseeko(fp,-4,SEEK_CUR);
						fprintf(stderr,"    TRMP PID : 0x%04x\n",trmp_pid);
                    }
					fseeko(fp,length,SEEK_CUR);
					read += 2 + length;
				}
				section_length -= 7 + 2 + program_info_length + 4;
				read = 0;
				while(read < section_length) {
					unsigned char stream_type;
					unsigned short pid;
					unsigned short length;
					fread(&stream_type,1,1,fp);
					fread(&pid,2,1,fp);
					fread(&length,2,1,fp);
					pid = OSSwapBigToHostInt16(pid) & 0x1fff;
					length = OSSwapBigToHostInt16(length) & 0xfff;
					if(stream_type == 0x02) {
						fprintf(stderr,"    MPEG-2 video PID : 0x%04x\n",pid);
						vid_pid = pid;
					}
					else if(stream_type == 0x0f) {
						fprintf(stderr,"    MPEG-2 AAC PID : 0x%04x\n",pid);
						aud_pid = pid;
					}
					unsigned char tag;
					fread(&tag,1,1,fp);
					if(tag == 0xf6) {
						fprintf(stderr,"    TRMP descriptor found\n");
					}
					fseeko(fp,length-1,SEEK_CUR);
					read += 5 + length;
				}
				fseeko(fp,packet_beginning,SEEK_SET);
			}
			else if(pid == ecm_pid) {
				fprintf(stderr,"PID: 0x%x (ECM)\n",pid);
				fprintf(stderr,"  adaptation_field_control: 0x%x\n",adaptation_field_control);
				fprintf(stderr,"  payload_unit_start_indicator: %d\n",payload_unit_start_indicator);
				off_t packet_beginning = ftello(fp);
				if(adaptation_field_control & 0x2) {
					fseeko(fp,fgetc(fp),SEEK_CUR);
				}
                if(payload_unit_start_indicator) {
                    /* 1 byte pointer_field exists at the beginning of the payload */
					fseeko(fp,1,SEEK_CUR);
                }
                /*-------------------------
                bit
                 8   table descriptor (0x82 or 0x83)
                 1   section syntax indicator
                 1   '1'
                 2   '11'
                12   section length
                16   table descriptor extension
                 2   '11'
                 5   version number
                 1   current next indicator
                 8   section number
                 8   last section number
                 n   data
                32   CRC32
                ---------------------------*/
				unsigned short section_length;
				fseeko(fp,1,SEEK_CUR);
				fread(&section_length,2,1,fp);
				section_length = OSSwapBigToHostInt16(section_length) & 0xfff;
				fseeko(fp,5,SEEK_CUR);
				section_length -= 5 + 4;
				int i;
				for(i=0;i<section_length;i++) {
					fprintf(stderr,"0x%02x,",fgetc(fp));
				}
				putchar('\n');
				/*int i;
				for(i=0;i<184;i++) {
					fprintf(stderr,"%02x ",fgetc(fp));
					if((i&0xf) == 0xf) putchar('\n');
				}
				putchar('\n');*/
				ecm_found++;
				//if(ecm_found == 1) break;
				fseeko(fp,packet_beginning,SEEK_SET);
			}
			else if(pid == vid_pid) {
				#if 0
				if(ecm_found) {
				fprintf(stderr,"PID: 0x%x (video)\n",pid);
				fprintf(stderr,"  adaptation_field_control: 0x%x\n",adaptation_field_control);
				fprintf(stderr,"  transport_scramble_control: 0x%x\n",(header[2]>>6)&0x3);
				fprintf(stderr,"  payload_unit_start_indicator: %d\n",payload_unit_start_indicator);
				
					int i;
					for(i=0;i<184;i++) {
						fprintf(stderr,"0x%02x, ",fgetc(fp));
						if((i&0xf) == 0xf) putchar('\n');
					}
					putchar('\n');
					break;
				}
				#endif
			}
			//if(((header[2]>>6)&0x3) != 0) break;
			fseeko(fp,184,SEEK_CUR);
		}
		else fseeko(fp,1,SEEK_CUR);
	}
	return 0;
}