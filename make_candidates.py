import sys
import os
import pandas as pd
from sticky_pi_api.client import LocalClient

LOCAL_CLIENT_DIR = '/home/quentin/sticky_pi_client'

if __name__ == "__main__":
    OUTFILE = sys.argv[1]

    assert os.path.basename(OUTFILE) != b'candidate_labels.csv', os.path.basename(OUTFILE)
    assert os.path.isdir(os.path.dirname(OUTFILE))

    cli = LocalClient(LOCAL_CLIENT_DIR)

    o = cli.get_tiled_tuboid_series_itc_labels(
        [{'device': '%', 'start_datetime': '2010-01-01_00-00-00', 'end_datetime': '2120-01-01_00-00-00'}])

    df = pd.DataFrame(o)
    df = df[['tuboid_id'] + [tax + '_itc' for tax in ['type', 'order', 'family', 'genus', 'species']]]
    df = df.rename(lambda x: x.split('_itc')[0], axis=1)
    df.to_csv(OUTFILE, index=False)
