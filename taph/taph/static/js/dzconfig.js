elem = document.getElementsByClassName("dzone-class");
// var tempurl = console.log(elem.id)
var tempurl = "/form-submit"
function sleep (time) {
    return new Promise((resolve) => setTimeout(resolve, time));
}
Dropzone.options.myDropzone = {
    addRemoveLinks: true,
    uploadMultiple: true,
    thumbnailWidth: 30,
    thumbnailHeight: 30,
    autoProcessQueue: false,
    paramName: "dzfile",
    parallelUploads: 50,
    init: function() {
        myDropzone = this;
        this.element.querySelector("button[type=submit]").addEventListener("click", function(e) {
        e.preventDefault();
        e.stopPropagation();
        myDropzone.processQueue();
        myDropzone.on("successmultiple", function(files, response) {
            sleep(500).then(() => {
            location.href=tempurl;
            });
        });
    });
  }
};

$( "img" ).each( function() {
    var $img = $( this );
    $img.height( $img.height() * .8 );
});
