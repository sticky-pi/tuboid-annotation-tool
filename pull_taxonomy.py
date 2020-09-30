import json
from ete3 import NCBITaxa
OUTFILE = 'taxonomy.json'
ncbi = NCBITaxa()
# ncbi.update_taxonomy_database()
insects = 'Insecta'
insecta_taxid = ncbi.get_name_translator([insects])[insects][0]

tree = ncbi.get_descendant_taxa(insecta_taxid,collapse_subspecies=True,return_tree=True)

{'Insecta':{}}

ranks = ['order', 'family', 'genus', 'species']

for n in tree.traverse():
  if n.rank not in ranks:
    n.delete()

def recurse(tree, depth=0, max_depth=4):
  out = [(tree.name, tree.rank, depth)]
  for subtree in tree.get_children():
    out.extend(recurse(subtree, depth +1))
  return out
  
valid_ids = []
for name, r, depth in recurse(tree):
  if ranks[depth-1] == r or depth==0 :
    valid_ids.append(name)
  else:
    print( 'Removing: ', name, r, depth)

tree.prune(valid_ids)



name_map = ncbi.get_taxid_translator([t.taxid for t in tree.get_descendants()] + [tree.taxid])


def tree_as_dict(tree, name_map):
  key = name_map[tree.taxid]
  out = {key: {}}
  for subtree in tree.get_children():
    out[key].update(tree_as_dict(subtree, name_map))
  return out
  
d = tree_as_dict(tree, name_map)
d['Background'] = {}
d['Ambiguous'] = {}

with open(OUTFILE, 'w') as f:
  json.dump(d, f)

