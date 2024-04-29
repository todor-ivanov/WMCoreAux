def recurLen(ob):
    obLen = 0
    print(f"ob: {ob}")
    if isinstance(ob,  collections.abc.Mapping) or isinstance(ob, list):
        obLen += len(ob)
        for obb in ob:
            print(f"obb: {obb}")
            if obb and isinstance(ob, list):
                print(f"obb: {obb} recuring into list {obb}")
                obLen += recurLen(obb)
            elif obb and isinstance(ob, collections.abc.Mapping):
                print(f"obb: {obb} recuring into mapping {obb}")
                obLen += recurLen(ob[obb])
    elif ob and isinstance(ob, collections.abc.Sized):
        print(f"ob {ob} is sizeble - measuring")
        obLen += len(ob)
    elif ob:
        print(f"ob {ob} is NOT sizeble - increasing by 1")
        obLen += 1
    else:
        print(f"ob {ob} is NOT counted")
    print(f"ob {ob} len:{obLen}")
    return obLen
