"""
Run Analysis
05.21.2017
"""
import os
import os.path as op
import matplotlib as mpl

from utils.AnalysisObjs import *

def run_summary():
    summary_obj = summary(PATH_res)
    summary_obj.plot_ts_uzf_sums()
    # summary_obj.plot_hypsometry()
    # summary_obj.plot_hist_head()

    # summary_obj.plot_heads_1loc() # for methods; mf vs swmm at surf leak
    # summary_obj.untruncated(20,19)  # for discussion; untruncated init conditions

def run_dtw():
    dtw_obj = dtw(PATH_res)
    dtw_obj.plot_area_hours()

def run_runoff():
    runobj_obj = runoff(PATH_res)
    runobj_obj.plot_ts_total()

def run_sensitivity():
    sensitivityObj = sensitivity(PATH_res, 'S4H', testing=False)
    # sensitivityObj.totals('inf')
    # sensitivityObj.totals('evap')

    ### run two plots:
    sensitivityObj.compare()

PATH_res  = op.join('/', 'Volumes', 'BB_4TB', 'Thesis', 'Results_Default')
# PATH_sens = op.join('/', 'Volumes', 'BB_4TB', 'Thesis', 'Results_S4H')
PATH_save = op.join(op.expanduser('~'), 'Google_Drive', 'Thesis_git', 'Figs_Results')
# run_summary()
# run_dtw()
# run_runoff()

run_sensitivity()
savefigs(PATH_save)

# plt.show()
