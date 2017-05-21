"""
AnalysisObjs3.py
Refactored 05.21.17
"""
import BB
import os
import os.path as op
from components import bcpl

from collections import OrderedDict
import numpy as np
import pandas as pd
from scipy.interpolate import InterpolatedUnivariateSpline as spline

import matplotlib as mpl
import matplotlib.pyplot as plt
import matplotlib.gridspec as gridspec
from matplotlib.ticker import FormatStrFormatter

import geopandas
import shapely
from shapely.geometry import Point

class res_base(object):
    def __init__(self, path_result):
        self.path       = path_result
        self.path_picks = op.join(path_result, 'Pickles')
        self.path_data  = op.join('/', 'Users', 'bb', 'Google_Drive', 'WNC',
                                                           'Coupled', 'Data')
        self.path_fig   = op.join(self.path, 'Figures')
        self.path_gis   = op.join(op.expanduser('~'), 'Dropbox', 'win_gis')
        self.df_sys     = pd.read_pickle(op.join(self.path_picks, 'swmm_sys.df'))#.loc['2012-01-01-00':, :]
        self.df_xy      = pd.read_csv(op.join(self.path_data, 'Grid_XY.csv'),
                                                      index_col='Zone')
        self.slr_names  = self._get_slr()
        self.slr        = sorted(self.slr_names)
        self.sys_vars   = BB.uniq([slr.rsplit('_', 1)[0] for slr in self.df_sys.columns])

        self.ts_day     = self.df_sys.resample('D').first().index
        self.ts_hr      = self.df_sys.index
        self.df_swmm    = pd.read_csv(op.join(self.path_data, 'SWMM_subs.csv'),
                                                           index_col='Zone')
        self.subs       = self.df_swmm.index.values
        self.slr_sh     = ['0.0', '1.0', '2.0']
        self.seasons    = ['Winter', 'Spring', 'Summer', 'Fall']
        # to truncate time series to start at Dec 1, 2012; implement in pickling
        self.st         = '2011-12-01-00'
        self.end        = '2012-11-30-00'
        self.ts_yr_hr   = self.ts_hr[3696:-698]
        self.ts_yr_day  = self.ts_day[154:-30]
        self.nrows      = 74
        self.ncols      = 51

    def ts_all(self, param, loc=False, slr=0.0, dates=[0, -0], plot=False):
        """
        Pull a time series from a swmm binary '.out' file
        Arguments:
            Path to .out
            Param (eg 'precip')
            Loc ID number (eg 10735)
            Dates can be integers or datetimes
            Plot True if you want to see plots
        Returns:
            Pandas dataframe with datetime index
        """
        slr_name = self.slr_names[slr]
        out_file = op.join(self.path, slr_name, '{}.out'.format(slr_name))
        # map parameters to type, individual code, units (for plot), system code
        param_map = {'precip' : ['subcatchment,', ',0', 'mm', ',1'],
                     'flow'   : ['link,', ',2', 'm/s'],
                     'flood'  : ['node,', ',5', 'cms', ',10'],
                     'inf'    : ['subcatchment,', ',3', 'mm/hr?', ',3'],
                     'evap'   : ['subcatchment,', ',2', 'mm/hr?', ',13'],
                     'run'    : ['subcatchment,', ',4', 'cms', ',4'],
                     'head'   : ['subcatchment,', ',6', 'm'],
                     'soil'   : ['subcatchment,', ',7', 'theta'],
                     'gwout'  : ['subcatchment,', ',5', '??', '6?'],
                     'pet'    : ['subcatchment,', '', 'mm/hr?', ',14'],
                    }
        #swmtbx.listdetail(out_file, 'link')
        if loc:
            t_series_raw = swmtbx.extract(out_file, param_map[param][0] + str(loc)
                                                         + param_map[param][1])
        else:
            t_series_raw = swmtbx.extract(out_file, 'system' + param_map[param][3]
                                                         + param_map[param][3])
        t_series = t_series_raw[dates[0]:]

        if plot:
            t_series.resample('MS').mean().plot()
            plt.ylabel (param_map[param][2])

        return t_series

    def ts_gage(self, row, col):
        """ Pull ts from a uzf gage file. Give 0 idx, it uses 1 idx row/col """
        ### find correct uzf file
        gage_ext = op.splitext(self._find_gage(row, col))[1]
        df_all   = pd.DataFrame(index=self.ts_day)
        for slr in self.slr:
            """ ======================================================== FIX """
            slr_name  = self.slr_names[slr]
            path_gage = op.join(self.path, slr_name, slr_name+gage_ext)
            ### pull data from file
            data = []
            with open(path_gage) as input:
                for i in range(3):
                    next(input)
                for line in input:
                    line = line.strip().split()
                    if len(line) == 6:
                        layer = int(line.pop(0))
                        time = float(line.pop(0))
                        head = float(line.pop(0))
                        uzthick = float(line.pop(0))
                    depth = float(line.pop(0))
                    watercontent = float(line.pop(0))
                    # data.append([layer, time, head, uzthick, depth, watercontent])
                    data.append([time, head, watercontent])
            # df_wc = pd.DataFrame(data, columns=['layer', 'time', 'head', 'uzthick',
                                                        #    'depth', 'watercontent'])

            cols  = ['{}_{}'.format(var, slr) for var in ['Time', 'Head', 'Water']]
            df_wc = pd.DataFrame(data, columns=cols)
            # start_date = datetime(2011, 06, 30)

            df_wc = df_wc.groupby('Time_{}'.format(slr)).first().reset_index()

            df_wc.index = df_wc['Time_{}'.format(slr)].apply(lambda x:
                                           self.ts_day[0] + timedelta(days=x-1))
            df_wc.drop('Time_{}'.format(slr), 1, inplace=True)
            # print self.ts[0] + timedelta(days=1)
            df_all = pd.merge(df_all, df_wc, left_index=True, right_index=True, how='left')
        return df_all

    def _find_gage(self, row, col):
        """ Find the gage file for a specific location. Give 0 idx. """
        slr_name   = self.slr_names[0.0]
        regex      = re.compile('({}.uzf[0-9]+)'.format(slr_name))
        gage_files = [op.join(self.path, slr_name, uzfile) for uzfile
                                in os.listdir(op.join(self.path, slr_name))
                                if regex.search(uzfile)]
        for i, each in enumerate(gage_files):
            linecache.clearcache()
            nums = re.findall(r'\d+', linecache.getline(each, 1))
            ROW = int(nums[1])
            COL = int(nums[2])
            if ROW == row+1 and COL == col+1:
                return each
            else:
                continue
        return 'Gagefile for row {}, col {}, not found in: {}'.format(row, col, self.path)

    def _load_swmm(self, var='run', scen=False):
        """
        Load Pickled SWMM (full grid) Arrays
        Args:
            var = 'run' or 'heads'
            slr = 0.0, 1.0, or 2.0 to return that array
        Returns : Dictionary of SLR : array of hrs x row x col
        """
        dict_var = {}
        for slr in self.slr:
            dict_var[str(slr)] = np.load(op.join(self.path_picks,
                                    'swmm_{}_grid_{}.npy').format(var, slr))
        if scen:
            return dict_var[str(slr)]

        return dict_var

    def _load_fhd(self):
        """ Load Pickled FHD Arrays into a Dictionary of SLR: arr"""
        dict_fhd         = {}
        for slr in self.slr:
            fhd_pickle    = 'heads_{}.npy'.format(slr)
            pickle_file   = op.join(self.path_picks, fhd_pickle)
            dict_fhd[slr] = (np.load(pickle_file))
        return dict_fhd

    def _load_uzf(self, kind=False, scen=False):
        """ Load Pickled UZF Arrays """
        # ordered dict helps with plotting
        dict_uzf = OrderedDict()
        for var in ['surf_leak', 'uzf_rch', 'uzf_et', 'uzf_run']:
            pickle_files = [op.join(self.path_picks, pick_file) for pick_file in
                            os.listdir(self.path_picks) if pick_file.startswith(var)]
            tmp_dict = OrderedDict()
            for leak_mat in pickle_files:
                SLR = float(op.basename(leak_mat).split('_')[2][:-4])
                tmp_dict[SLR] = np.load(leak_mat)
            # list of dictionary of scenario (0.0) : 74x51x549 matrix
            dict_uzf[var] = tmp_dict
        try:
            if scen:
                return dict_uzf[kind][scen]
            else:
                return dict_uzf[kind]
        except:
            return dict_uzf

    def _get_slr(self):
        """
        Get the correct SLR Name from the Directories
        Return dict of SLR: Slr Name
        """
        dict_slrnames = {}
        for directory in os.listdir(self.path):
            if directory.startswith('SLR'):
                slr = float(directory.split('-')[1][:3])
                dict_slrnames[slr] = directory
        return dict_slrnames

    def save_cur_fig(self):
        """ Saves the current fig """
        try:
            curfig = plt.gcf()
        except:
            raise ValueError('No Current Figure Available')
        if not op.isdir(self.path_fig):
            os.makedirs(self.path_fig)
        curfig.savefig(op.join(self.path_fig, curfig.get_label()))

    @staticmethod
    def fill_grid(ser):
        """ Create WNC grid from a series with 1 indexed zones and values """
        mat = np.zeros([3774])
        mat[:] = np.nan
        # parse numpy array where column 1 is an index
        if isinstance(ser, np.ndarray):
            for i, idx in enumerate(ser[1, :]):
                idx -= 10001
                mat[int(idx)] = ser[0, i]
            return mat.reshape(74,51)

        # parse series
        else:
            idx = ser.index
            if not np.nansum(ser) == 0:
                for i in idx:
                    mat[int(i)-10001] = ser[i]
            else:
                for i in idx:
                    mat[int(i)-10001] = 1

            return mat.reshape(74,51)

class summary(res_base):
    """ Overall information """
    def __init__(self, path_results, row=0, col=2):
        res_base.__init__(self, path_results)
        self.row, self.col  = row, col
        self.loc_1d         = bcpl.cell_num(self.row, self.col) + 10000
        self.arr_land_z     = np.load(op.join(self.path_data, 'Land_Z.npy'))
        self.df_grid        = pd.read_csv(op.join(self.path_data, 'MF_grid.csv'))

    def plot_ts_uzf_sums(self):
        """
        Plot Sum of Recharge, ET,  at all locs, each step, monthly mean
        PLot Precipation
        """
        var_map  = OrderedDict([('uzf_rch','GW  Recharge'), ('uzf_et', 'GW  ET')])
        dict_uzf = self._load_uzf()

        df_sums  = pd.DataFrame({'Precip':self.df_sys['Precip_{}'.format(
                                        self.slr[0])]}).resample('D').sum()
        for name, arr in dict_uzf.items():
            if not name in var_map:
                continue
            for slr in self.slr:
                mat_sum = arr[slr].reshape(550,-1).sum(1)
                df_sums['{}_{}'.format(var_map[name], slr)] = mat_sum

        # truncate init conditions and resample to monthly
        df_mon = abs(df_sums).loc[self.st:self.end, :].resample('MS').mean()

        fig    = plt.figure()
        axe    = []
        gs     = gridspec.GridSpec(3, 2)
        axe.append(fig.add_subplot(gs[:2, 0]))
        axe.append(fig.add_subplot(gs[:2, 1]))
        axe.append(fig.add_subplot(gs[2, :]))

        for i, var in enumerate(var_map.values()):
            df_slr   = df_mon.filter(like=str(var))
            df_slr.plot(ax=axe[i], title=var, sharey=True)

        df_mon.Precip.plot(ax=axe[-1], title='Precipitation')

        ### Y AXES
        axe[0].set_ylabel('Volume for whole model, in cubic meters', labelpad=10)
        axe[0].set_ylim(10000, 200000)
        axe[2].set_ylabel('Depth, in millimeters', labelpad=35)

        ### X AXES --- todo
        # axe[i].set_xticklabels(df_mon.index.map(lambda t: t.strftime('%b')))
        # fig.autofmt_xdate()

        ### ADJUST
        # fig.subplots_adjust(left=None, right=0.95, wspace=0.15)
        gs.update(bottom=0.075, hspace=0.6, wspace=0.15)
        # axe[2].set_labelpad(5)

        fig.set_label('ts_summary')

        return fig

    def plot_land_z(self):
        """
        plot land surface 2d - do this in arc (interp is cleaner)
        should interpolate it and then mask it (basically what i did in arc!
        """
        arr_grid_z        = self.arr_land_z.reshape(self.nrows, self.ncols)
        arr_grid_active   = self.df_grid.IBND.values.reshape(self.nrows, self.ncols)
        arr_grid_z_active = np.where(arr_grid_active > 0, arr_grid_z, 11)
        fig, axes  = plt.subplots()
        im         = axes.imshow(arr_grid_z_active, plt.cm.jet)
        cbar_ax    = fig.add_axes([0.85, 0.175, 0.025, 0.6], xlabel='Elevation (m)')
        fig.colorbar(im, cbar_ax, spacing='proportional')
        axes.grid('off')
        axes.set(title='Land Surface Elevation')

    def plot_hypsometry(self, bins=50):
        """ Histogram of Elevations of Model Cells """
        fig, axes       = plt.subplots()
        arr_active      = np.where(self.arr_land_z <= 0, np.nan, self.arr_land_z)
        arr_cln         = arr_active[~np.isnan(arr_active)]
        n, bin_edges, _ = axes.hist(arr_cln, bins=bins, facecolor='darkblue',
                        alpha=0.825, rwidth=0.55, align='left', histtype='bar')

        axes.set_xlabel('Elevation (m)', labelpad=20, size=13)
        axes.set_ylabel('Frequency', labelpad=20, size=13)
        # format ticks
        axes.xaxis.set_ticks(np.linspace(0.0, 9.0, 10))
        axes.xaxis.set_major_formatter(FormatStrFormatter('%0.1f'))
        axes.set_xlim(-0.25, 8.25)
        fig.set_label('hypsometry')
        return fig

    def plot_hist_head(self, bins=25):
        """ Create a Histogram of Heads for each SLR Scenario """
        # dict_heads = self._load_swmm('heads')
        dict_heads  = self._load_fhd()
        fig         = plt.figure()
        axe         = []
        gs          = gridspec.GridSpec(3, 3)
        colors      = ['darkblue', 'darkgreen', 'darkred']
        # colors      = ['#4C72B0', '#55A868', '#C44E52'] # seaborn defaults
        axe.append(fig.add_subplot(gs[:2, 0]))
        axe.append(fig.add_subplot(gs[:2, 1], sharey=axe[0]))
        axe.append(fig.add_subplot(gs[:2, 2], sharey=axe[0]))
        axe.append(fig.add_subplot(gs[2, :]))

        for i, (slr, arr) in enumerate(dict_heads.items()):
            arr_cln   = np.where(arr < 0, np.nan, arr) # for fhd
            arr_cln   = arr_cln[~np.isnan(arr_cln)].flatten()[154:-30] # for both
            # for converting absolute counts to between 0 1
            weights   = (np.ones_like(arr_cln)/len(arr_cln))

            mean, std       = arr_cln.mean(), arr_cln.std()
            n, bin_edges, _ = axe[i].hist(arr_cln, bins=bins, #normed=True,
                            align='left', rwidth=0.55,  #weights=weights,
                            histtype='bar', facecolor=colors[i], alpha=0.825
                            )

            colname = 'SLR-{} m'.format(slr)
            center  = (bin_edges[:-1] + bin_edges[1:]) / 2
            # fit a line to the middles of the bins
            fit     = spline(bin_edges[:-1], n)
            # fit  = interpolate.InterpolatedUnivariateSpline(center, n)
            x2      = np.linspace(bin_edges[:-1].min(), bin_edges[:-1].max(), 1000)
            # x2   = np.linspace(center.min(), center.max(), 1000)
            y       = fit(x2)

            # plot distributions on the bottom
            axe[3].plot(x2, y, color=colors[i], label=colname)

            axe[i].set_title('SLR: {} (m)'.format(slr))
            axe[i].xaxis.set_ticks(np.linspace(0.0, 9.0, 10.0))
            axe[i].xaxis.set_major_formatter(FormatStrFormatter('%0.1f'))
            axe[i].set_xlim(-0.25, 7.7)
            axe[0].set_ylabel('Frequency', labelpad=15)
            # axe[1].set_xlabel('GW Head (m)', labelpad=15)

        # turn off shared ticks
        plt.setp(axe[1].get_yticklabels(), visible=False)
        plt.setp(axe[2].get_yticklabels(), visible=False)

        # bottom subplot properties
        axe[3].legend()
        axe[3].set_xlabel('GW Head (m)', labelpad=10)
        axe[3].set_ylabel('Frequency', labelpad=15)
        axe[3].xaxis.set_ticks(np.linspace(0.0, 9.0, 10))
        axe[3].xaxis.set_major_formatter(FormatStrFormatter('%0.1f'))
        axe[3].set_xlim(-0.05, 7.7)
        gs.update(bottom=0.075, hspace=0.3, wspace=0.15)
        fig.set_label('hist_head')

class runoff(res_base):
    def __init__(self, path_result):
        res_base.__init__(self, path_result)
        self.df_area = pd.read_pickle(op.join(self.path_picks, 'percent_vols.df'))
        self.vols    = BB.uniq([float(vol.split('_')[1]) for vol in self.df_area.columns])
        self.dict    = self._load_swmm('run')

    def plot_ts_total(self):
        """ Monthly Times series of Total System Runoff """
        df_run    = self.df_sys.filter(like='Runoff').resample('MS').mean().loc[self.st:self.end, :]
        fig, axes = plt.subplots()
        colnames  = ['SLR: {} m'.format(c.split('_')[-1]) for c in df_run.columns]
        df_run.columns = colnames
        # could probably change global alpha and color cycles
        df_run.plot.bar(ax=axes, color=['darkblue', 'darkgreen', 'darkred'], alpha=0.75)
        axes.set_xticklabels(df_run.index.map(lambda t: t.strftime('%b')))
        axes.legend(loc='upper left')
        axes.set_xlabel('Time', labelpad=15, size=14)
        axes.set_ylabel('Runoff Rate (CMS)', labelpad=15, size=14)
        axes.yaxis.grid(True)
        axes.xaxis.grid(False)

        fig.autofmt_xdate(bottom=0.2, rotation=20, ha='center')
        fig.set_label('total_monthly_runoff')

    def shp_chg(self):
        """ Write shapefile of 2d change due to SLR """
        low         = self.dict['0.0'][3696:-698, :, :].sum(0).reshape(-1)
        med         = self.dict['1.0'][3696:-698, :, :].sum(0).reshape(-1)
        high        = self.dict['2.0'][3696:-698, :, :].sum(0).reshape(-1)

        chg_1       =  (med  - low) / med  * 100
        chg_2       =  (high - med) / high * 100
        df          = self.df_xy.loc[:, ['POINT_X', 'POINT_Y']]
        df['1_0']   = chg_1
        df['2_0']   = chg_2
        df['geom']  = df.apply(lambda x: Point((float(x.POINT_X), float(x.POINT_Y))), axis=1)
        geo_df      = geopandas.GeoDataFrame(df, geometry='geom')
        geo_df.to_file(op.join(self.path_gis, 'Runoff_Chg.shp'), driver='ESRI Shapefile')
        print 'Runoff ShapeFile Written: {}'.format(op.join(self.path_gis, 'Runoff_Chg.shp'))

    def plot_area_vol(self):
        """ Plot area vs hours, curves of SLR, subplots of rates """
        area_bins   = np.linspace(1, 100, 80)
        fig, axes   = plt.subplots(2, 2, True, True)
        # title       = fig.suptitle('percent area experiencing given runoff depth')
        axe         = axes.ravel()
        for i, vol in enumerate(self.vols):
            cols        = [col for col in self.df_area.columns if col.split('_')[-1] == str(vol)]
            df_area_one = self.df_area[cols]
            df_area_one.columns = ['SLR: {} m'.format(slr.split('_')[0]) for slr in df_area_one.columns]
            df_days     = pd.DataFrame(index=area_bins, columns=df_area_one.columns)
            for area in area_bins:
                df_days.loc[area, :] = (df_area_one>=area).sum()

            df_days.plot(ax=axe[i], title='Depth >= {} mm'.format(vol),
                         color=['darkblue', 'darkgreen', 'darkred'], alpha=0.5)

            axe[i].set_xlabel('% Area', labelpad=15, size=14)
            axe[i].set_ylabel('Hours',  labelpad=15, size=14)
            axe[i].xaxis.grid(False)
            axe[i].yaxis.grid(True)
        fig.subplots_adjust(left=0.075, right=0.92, wspace=0.15, hspace=0.15)
        fig.set_label('runoff_area')
        return fig

    def __leak_Vs_runoff(self):
        """
        Compare surface leakage and runoff for whole simulation
        Runoff units may be off / and uzf. both time and area (200 * 200 * 1455?)
        Internal Check for Me
        """
        area    = 200. * 200.
        arr_uzf = abs(self._load_uzf('surf_leak', 2.0).reshape(len(self.ts_day), -1).sum(1)/area)
        ser_uzf = pd.Series(arr_uzf, index=self.ts_day).loc[self.st:self.end]
        arr_run = np.nansum(self._load_swmm('run', 2.0).reshape(len(self.ts_hr), -1), 1)/area#*3600
        ser_run = pd.Series(arr_run, index=self.ts_hr).resample('D').sum().loc[self.st:self.end]
        df      = pd.DataFrame({'Leak_2.0' : ser_uzf, 'Run_2.0' : ser_run}, index=ser_run.index)
        df.plot(subplots=True)

class dtw(res_base):
    def __init__(self, path_result):
        res_base.__init__(self, path_result)
        # pickle converted this to a year
        self.df_year  = pd.read_pickle(op.join(self.path_picks, 'dtw_yr.df'))
        self.df_area  = pd.read_pickle(op.join(self.path_picks, 'percent_at_surface.df'))#.loc['2011-12-01-00':, :]
        self.dtws     = BB.uniq([float(dtw.split('_')[1]) for dtw in self.df_area.columns])

    def plot_area_hours(self):
        """ Plot area vs hours, curves of SLR, subplots of DTW """
        area_bins   = np.linspace(0, 100, 40)
        fig, axes   = plt.subplots(2, 2, True, True)
        # title       = fig.suptitle('percent area within given depth to water')
        axe         = axes.ravel()
        for i, dtw in enumerate(self.dtws):
            df_area_one = self.df_area.filter(like=str(dtw)).loc[self.st:self.end, :]
            df_area_one.columns = ['SLR: {} m'.format(slr.split('_')[0])
                                        for slr in df_area_one.columns]
            df_hrs     = pd.DataFrame(index=area_bins, columns=df_area_one.columns)
            for area in area_bins:
                df_hrs.loc[area, :] = (df_area_one>=area).sum()
            BB.fill_plot(df_hrs, axe[i], title='DTW <= {} m'.format(dtw))
            axe[i].set_xlabel('% Area', size=15, labelpad=15)
            axe[i].set_ylabel('Hours', size=15, labelpad=15)
            axe[i].xaxis.grid(False)
            axe[i].legend(loc='lower left', frameon=True, shadow=True, facecolor='white')
            axe[i].set_ylim((0, len(df_area_one)*1.10))
            # axe[i].legend.get_frame(facecolor='white')
        fig.set_label('dtw_area')
        return fig

    def plot_hist_dtw(self, bins=10):
        """ Create a Histogram of DTW for each SLR Scenario """
        fig         = plt.figure()
        axe         = []
        gs          = gridspec.GridSpec(3, 3)
        colors      = ['darkblue', 'darkgreen', 'darkred']
        # colors      = ['#4C72B0', '#55A868', '#C44E52'] # seaborn defaults
        axe.append(fig.add_subplot(gs[:2, 0]))
        axe.append(fig.add_subplot(gs[:2, 1], sharey=axe[0]))
        axe.append(fig.add_subplot(gs[:2, 2], sharey=axe[0]))
        axe.append(fig.add_subplot(gs[2, :]))

        for i, slr in enumerate(self.df_year):
            mask_yr = np.ma.masked_invalid(self.df_year[slr].values).compressed()
            n, bin_edges, _ = axe[i].hist(mask_yr, bins=bins,
                            align='left', rwidth=0.55, histtype='bar',
                            facecolor=colors[i], alpha=0.825)

            colname = 'SLR-{} (m)'.format(slr)
            centers = (bin_edges[:-1] + bin_edges[1:]) / 2      # for unsmoothed
            # fit a line to the middles of the bins
            fit     = spline(bin_edges[:-1], n)
            x2      = np.linspace(bin_edges[:-1].min(), bin_edges[:-1].max(), 1000)
            y       = fit(x2)

            # plot smoothed curve on the bottom
            axe[3].plot(x2, y, color=colors[i], label=colname)
            # axe[3].plot(centers, n, color=colors[i], label=colname) # unsmoothed

            axe[i].set_title('SLR: {} m'.format(slr))
            # axe[i].xaxis.set_ticks(np.linspace(0.0, 9.0, 10.0))
            axe[i].xaxis.set_major_formatter(FormatStrFormatter('%0.1f'))
            # axe[i].set_xlim(-0.25, 7.7)
            axe[0].set_ylabel('Frequency', labelpad=15)
            # axe[1].set_xlabel('GW Head (m)', labelpad=15)

        # turn off shared ticks
        plt.setp(axe[1].get_yticklabels(), visible=False)
        plt.setp(axe[2].get_yticklabels(), visible=False)

        # bottom subplot properties
        axe[3].legend()
        axe[3].set_xlabel('DTW (m)', labelpad=10)
        axe[3].set_ylabel('Frequency', labelpad=15)
        # axe[3].xaxis.set_ticks(np.linspace(0.0, 9.0, 10))
        axe[3].xaxis.set_major_formatter(FormatStrFormatter('%0.1f'))
        # axe[3].set_xlim(-0.05, 7.7)
        gs.update(bottom=0.075, hspace=0.3, wspace=0.15)
        fig.set_label('hist_dtw')

    def interesting(self, maxchg=-30, maxdtw=30.48):
        """ Make locs where signif changes due to SLR AND low dtw  units=cm """
        figures        = []
        self.df_year  *= 100
        df_inter       = pd.DataFrame(index=self.df_year.index)
        for i in range(len(self.slr_sh) - 1):
            slr_low            = float(self.slr_sh[i])
            slr_high           = float(self.slr_sh[i+1])
            chg_col            = 'chg_{}'.format(slr_high)
            df_inter[slr_low]  = self.df_year[slr_low]
            df_inter[slr_high] = self.df_year[slr_high]
            # max change will be a meter since that's diff in slr_sh
            df_inter[chg_col]  = df_inter[slr_high] - df_inter[slr_low]

            ### make the intersections
            df_inter['inter_{}'.format(slr_high)] = (
                                       df_inter.loc[:, slr_high].where(
                                      (df_inter.loc[:, slr_high]<maxdtw)
                                    & (df_inter.loc[:, chg_col].values<maxchg)))

        return df_inter

    def plot_interesting(self, maxchg=-10, maxdtw=30.48):
        df_inter         = self.interesting()
        for i in range(len(self.slr_sh) - 1):
            slr_low      = float(self.slr_sh[i])
            slr_high     = float(self.slr_sh[i+1])
            chg_col      = 'chg_{}'.format(slr_high)
            inter_col    = 'inter_{}'.format(slr_high)
            arr_change   = df_inter[chg_col].values.reshape(74, 51)
            arr_high_dtw = df_inter[slr_high].values.reshape(74, 51)
            arr_inter    = df_inter[inter_col].values.reshape(74, 51)

            ### PLOT
            fig, axes = plt.subplots(ncols=3)
            title     = fig.suptitle('Average DTW')
            axe       = axes.ravel()

            # plot change
            im = axe[0].imshow(arr_change, cmap=plt.cm.jet_r,
                                 vmin=-80, vmax=maxchg)
            axe[0].set(title='Change in DTW cm: {} m to {} m SLR'.format(
                                                    slr_low, slr_high))

            # plot dtw
            im2 = axe[1].imshow(arr_high_dtw, cmap=plt.cm.jet_r,
                                     vmin=0, vmax=maxdtw)
            axe[1].set(title='DTW cm for SLR: {} m '.format(slr_high))

            im3  = axe[2].imshow(arr_inter, cmap=plt.cm.jet_r)
            axe[2].set(title='Locations with Abs Change > {} cm and DTW < {} cm\
                              \nSLR: {} m to {} m'.format(-1*maxchg, maxdtw,
                                                         slr_low, slr_high))
        return

    def shp_interesting(self):
        """ Write shapefile of interesting change locations due to SLR """
        df_interest = self.interesting()
        df_xy       = self.df_xy.loc[:, ['POINT_X', 'POINT_Y']]
        df_xy.index = df_interest.index
        df          = pd.concat([df_interest, df_xy], axis=1)
        df.columns  = [str(col).replace('.', '_') for col in df.columns]

        df['geom']  = df.apply(lambda x: Point((float(x.POINT_X), float(x.POINT_Y))), axis=1)
        geo_df      = geopandas.GeoDataFrame(df, geometry='geom')
        geo_df.to_file(op.join(self.path_gis, 'DTW_Chg.shp'), driver='ESRI Shapefile')
        print 'DTW ShapeFile Written: {}'.format(op.join(self.path_gis, 'DTW_Chg.shp'))

def set_rc_params():
    plt.style.use('seaborn')

    mpl.rcParams['figure.figsize']   = (16, 9)
    mpl.rcParams['figure.titlesize'] = 14
    mpl.rcParams['axes.titlesize']   = 12
    mpl.rcParams['axes.labelsize']   = 11
    mpl.rcParams['savefig.dpi']      = 2000
    mpl.rcParams['savefig.format']   = 'pdf'
    # mpl.rcParams['figure.figsize']   = (18, 12) # for saving
    # matplotlib.rcParams['axes.labelweight'] = 'bold'
    for param in mpl.rcParams.keys():
        # print param
        pass

set_rc_params()