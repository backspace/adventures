# frozen_string_literal: true

portage_place = Region.create!(name: 'Portage Place')
food_court = Region.create!(name: 'Food Court', parent: portage_place)

arena = Region.create!(name: 'Arena')
winnipeg_square = Region.create!(name: 'Winnipeg Square')

Incarnation.create!(region: food_court,
                    concept: 'fill_in_the_blank',
                    mask: 'The food court is home to a plaque in memory of _____ Albert,' \
                          'a dedicated employee of the Portage Place Shopping Centre from 1990 to October 2002.',
                    answer: 'Olive')
Incarnation.create!(region: winnipeg_square,
                    concept: 'fill_in_the_blank',
                    mask: 'The third floor is home to, among others, the Scotiabank ________ Vice President.',
                    answer: 'District')
Incarnation.create!(region: arena,
                    concept: 'fill_in_the_blank',
                    mask: 'An enormous headline proclaims ____ quit!',
                    answer: 'Huns')

Incarnation.create!(region: food_court,
                    concept: 'bluetooth_collector',
                    answers: %w[device_a device_b])
