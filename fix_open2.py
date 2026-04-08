def patch(fp):
    with open(fp, "r") as f:
        c = f.read()

    c = c.replace('(_startSearchController.isAttached && (_startSearchController.isAttached && _startSearchController.isOpen))', '(_startSearchController.isAttached && _startSearchController.isOpen)')
    c = c.replace('(_destSearchController.isAttached && (_destSearchController.isAttached && _destSearchController.isOpen))', '(_destSearchController.isAttached && _destSearchController.isOpen)')
    
    with open(fp, "w") as f:
        f.write(c)

patch("lib/main.dart")
