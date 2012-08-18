#include <stdio.h>
#include <stdlib.h>
#include <gtk/gtk.h>
#include <gdk-pixbuf/gdk-pixbuf.h>

gboolean expose_event(GtkWidget *widget, GdkEventExpose *event, gpointer data){
  GdkPixbuf *pixbuf = (GdkPixbuf *)data;
 
  gdk_pixbuf_render_to_drawable (pixbuf, widget->window,
                 widget->style->fg_gc[GTK_STATE_NORMAL],
                 0, 0, 0, 0,
                 gdk_pixbuf_get_width(pixbuf),
                 gdk_pixbuf_get_height(pixbuf),
                 GDK_RGB_DITHER_NORMAL, 0, 0);
 
  return TRUE;
}

int main(int argc, char *argv[]){
  char *filename;
  int width, height; //画像の幅，高さ
  GtkWidget* window;
  GtkWidget* drawing_area;
  GdkPixbuf *pixbuf = NULL;
  GError *err = NULL;
 
  if((filename = argv[1]) == NULL) {
    fprintf(stderr, "usage: %s filename\n", argv[0]);
    exit(1);
  }

  gtk_init(&argc,&argv);
  gdk_rgb_init();
 
  //画像ファイルからpixbufを作成する
  if((pixbuf = gdk_pixbuf_new_from_file(filename, &err)) == NULL){
    // ユーザにエラーを報告して，エラーを解放する．
    fprintf (stderr, "Unable to read file: %s\n", err->message);
    g_error_free (err);
    exit(1);
  }

  //ウィンドウに表示するための準備
  window = gtk_window_new(GTK_WINDOW_TOPLEVEL);
  gtk_signal_connect (GTK_OBJECT (window), "destroy",
              GTK_SIGNAL_FUNC (gtk_main_quit), NULL);
 
  gtk_signal_connect(GTK_OBJECT(window), "destroy",
                     GTK_SIGNAL_FUNC(gtk_main_quit), NULL);
 
  drawing_area = gtk_drawing_area_new();
  width = gdk_pixbuf_get_width (pixbuf); //画像の幅をpixbufから取得する
  height = gdk_pixbuf_get_height (pixbuf); //画像の高さをpixbufから取得する
  gtk_drawing_area_size(GTK_DRAWING_AREA(drawing_area), width, height);
  gtk_container_add (GTK_CONTAINER (window), drawing_area);
  gtk_widget_show_all(window);
 
  gtk_signal_connect (GTK_OBJECT (drawing_area), "expose_event",
              GTK_SIGNAL_FUNC(expose_event), pixbuf);
 
  gtk_main();
 
  return 0;
} 

