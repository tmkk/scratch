#include <stdio.h>
#include <libavcodec/avcodec.h>
#include <libavformat/avformat.h>

int main(int argc, char *argv[])
{
	int i;
	av_register_all();
	
	if(argc<2) return 0;
	
	AVFormatContext *fCtx = NULL;
	if(avformat_open_input(&fCtx, argv[1], NULL, NULL) != 0) {
		fprintf(stderr,"avformat_open_input failure\n");
		return 0;
	}
	
	av_dump_format(fCtx, 0, argv[1], 0);
	
	AVCodec *codec = NULL;
	AVCodecContext *codecCtx = NULL;
	
	for(i=0;i<fCtx->nb_streams;i++) {
		printf("stream #%d\n", i );
		printf("codec type: %d\n", fCtx->streams[i]->codec->codec_type);
		if(AVMEDIA_TYPE_AUDIO != fCtx->streams[i]->codec->codec_type) continue;
		
		enum CodecID codec_id = fCtx->streams[i]->codec->codec_id;
		codec = avcodec_find_decoder(codec_id);
		if(codec) {
			codecCtx = fCtx->streams[i]->codec;
			break;
		}
	}
	
	if(!codec) goto end;
	
	printf("codec name: %s\n", codec->name );
	
	codecCtx->strict_std_compliance = FF_COMPLIANCE_EXPERIMENTAL;
	/*if(codec->capabilities & CODEC_CAP_TRUNCATED) {
		codecCtx->flags |= CODEC_FLAG_TRUNCATED;
	}*/
	
	/*if(avformat_find_stream_info(fCtx, NULL) < 0) {
		fprintf(stderr,"av_find_stream_info failure\n");
		return 0;
	}*/
	
	if(avcodec_open2(codecCtx, codec, NULL) < 0) {
		fprintf(stderr, "avcodec_open failure\n");
		goto end;
	}
	
	fprintf(stderr,"%d,%d,%d\n",codecCtx->sample_rate,codecCtx->channels,codecCtx->bits_per_coded_sample);
	fprintf(stderr,"%d,%d\n",av_get_audio_frame_duration(codecCtx,0),codecCtx->frame_size);
	fprintf(stderr,"%lld\n",fCtx->duration);
	
	int bps;
	
	switch (codecCtx->sample_fmt) {
		case AV_SAMPLE_FMT_U8: bps = 1; break;
		case AV_SAMPLE_FMT_S16: bps = 2; break;
		case AV_SAMPLE_FMT_S32: bps = 4; break;
		case AV_SAMPLE_FMT_FLT: bps = 4; break;
		default:
			fprintf (stderr, "Unsupported audio format %d\n", (int)codecCtx->sample_fmt);
			goto end;
	}
	
	FILE *fpw = fopen("tmp.pcm","wb");
	AVPacket packet;
	unsigned char *outbuf = malloc(AVCODEC_MAX_AUDIO_FRAME_SIZE);
	int n=0;
	while(1) {
		memset(&packet,0,sizeof(packet));
		packet.data = NULL;
		int ret;
		ret = av_read_frame(fCtx,&packet);
		if(ret == AVERROR_EOF) {
			fprintf(stderr, "EOF\n");
			break;
		}
		else if(ret < 0) {
			fprintf(stderr, "av_read_frame failure\n");
			break;
		}
		//fprintf(stderr,"%d,%d\n",av_get_audio_frame_duration(codecCtx,packet.size),codecCtx->frame_size);
#if 0
		int decoded = AVCODEC_MAX_AUDIO_FRAME_SIZE;
		ret = avcodec_decode_audio3(codecCtx,(short *)outbuf,&decoded,&packet);
		if(ret < 0) {
			fprintf(stderr, "avcodec_decode_audio4 failure\n");
			break;
		}
		fwrite(outbuf,1,decoded,fpw);
#else
		AVPacket tmpPkt;
		memcpy(&tmpPkt, &packet, sizeof(packet));
		//av_init_packet(&tmpPkt);
		while(tmpPkt.size > 0) {
			int decoded = 0;
			AVFrame *frame = avcodec_alloc_frame();
			ret = avcodec_decode_audio4(codecCtx,frame,&decoded,&tmpPkt);
			//ret = avcodec_decode_audio3(codecCtx,(short *)outbuf,&decoded,&tmpPkt);
			if(ret < 0) {
				fprintf(stderr, "avcodec_decode_audio4 failure\n");
				break;
			}
			//fprintf(stderr,"%d,%d,%d\n",tmpPkt.size,ret,decoded);
			tmpPkt.size -= ret;
			tmpPkt.data += ret;
			if(decoded) {
				fwrite(frame->data[0],1,bps * codecCtx->channels * frame->nb_samples,fpw);
				fprintf(stderr,"%d samples written\n",frame->nb_samples);
				//fwrite(outbuf,1,decoded,fpw);
			}
			av_free(frame);
		}
#endif
		if(packet.data) av_free_packet(&packet);
	}
	fclose(fpw);
	
	avcodec_close(codecCtx);
	
  end:
	avformat_close_input(&fCtx);
	
	return 0;
}