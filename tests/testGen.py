import pdb

# def testGen():
#     while True:
#         rep = (yield)
#         rep.append(1)

# for i in range(10):
#     print(next(testGen()))

def coroutine(func):
    """
    _coroutine_

    Decorator method used to prime coroutines

    """
    def start(*args,**kwargs):
        cr = func(*args,**kwargs)
        next(cr)
        return cr
    return start


@coroutine
def fileHandler():
    report=0
    while True:
        report, node = (yield report)
        lfn = node['lfn']
        report.append(lfn)

pdb.set_trace()

del(x)
for i in range(10):
    tp = ([],{'lfn': i})
    x=[x, fileHandler().send(tp)]
    print(x)
