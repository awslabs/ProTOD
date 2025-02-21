$(document).ready(function () {
    $("#ckbCheckAll").click(function () {
        $(".regions").prop('checked', $(this).prop('checked'));
    });

    $(".regions").change(function(){
        if (!$(this).prop("checked")){
            $("#ckbCheckAll").prop("checked",false);
        }
    });
});

$(document).ready(function () {
    $("#ckbCheckAll2").click(function () {
        $(".checks").prop('checked', $(this).prop('checked'));
    });

    $(".checks").change(function(){
        if (!$(this).prop("checked")){
            $("#ckbCheckAll2").prop("checked",false);
        }
    });
});
